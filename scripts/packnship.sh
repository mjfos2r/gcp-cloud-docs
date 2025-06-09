#!/usr/bin/env bash

# script to compress, hash, and upload a run to the specified gcloud bucket.
# data will be hashed with md5 and compressed via tar and pigz, and then
# a json with bucket paths will be output to the terminal!

set -euo pipefail
shopt -s nullglob

# -- CONFIGURATION ------------------------------------------------------------#
READS_FORMAT="fastq"
THREADS="${PIGZ_THREADS:-4}" # floor it to 19 with export PIGZ_THREADS=19
WORKSPACES=(
  "[redacted]"
)
BUCKET_PATHS=(
  "[redacted]"
)
# -----------------------------------------------------------------------------#

# Colors for output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

# -- Functions ----------------------------------------------------------------#
usage() { echo "Usage: $0 <run_dir>"; exit 1; }


find_files() {
  local run_dir="$1"
  local -n reads_dir="$2"
  local -n summary="$3"
  local -n summary_md5="$4"
  local reads_type="$5" # bam_pass or fastq_pass

  mapfile -t reads_matches < <(find "$run_dir" -type d -name "${reads_type}_pass")
  mapfile -t summary_matches < <(find "$run_dir" -type f -name "sequencing_summary_*.txt")

  if [[ ${#reads_matches[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: Cannot locate reads directory for '$reads_type' in $run_dir${NC}"
    exit 1
  elif [[ ${#reads_matches[@]} -gt 1 ]]; then
    echo -e "${RED}ERROR: Multiple reads directories found:${NC}"
    printf ' - %s\n' "${reads_matches[@]}"
    exit 1
  else
    reads_dir="${reads_matches[0]}"
    echo -e "${GREEN}Found reads directory:${NC} $reads_dir"
  fi

  if [[ ${#summary_matches[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: Cannot locate sequencing summary in $run_dir${NC}"
    exit 1
  elif [[ ${#summary_matches[@]} -gt 1 ]]; then
    echo -e "${RED}ERROR: Multiple sequencing summaries found:${NC}"
    printf ' - %s\n' "${summary_matches[@]}"
    exit 1
  else
    summary="${summary_matches[0]}"
    summary_md5="$(basename "${summary}").md5"
    echo -e "${GREEN}Found sequencing summary:${NC} $summary"
  fi
}

find_samplesheet() {
  local dest_bucket="$1"
  local run_id="$2"
  local -n samplesheet="$3"

  samplesheet="$(dirname "$dest_bucket")/samplesheets/${run_id}.csv"
  # ok, using the bucket and run_id, check for the samplesheet and if absent, merely print
  # a warning that it must be uploaded to the specified path before execution.

  if gsutil -q stat "$samplesheet" > /dev/null 2>&1; then
    echo -e "${GREEN}Samplesheet found in bucket!${NC}"
  else
    echo ""
    echo "!!!!"
    echo -e "${YELLOW}WARNING: Please upload the samplesheet to the bucket before demultiplexing!${NC}"
    echo "Expected path:     $samplesheet"
    echo "Expected filename: ${run_id}.csv"
    echo "!!!!"
    echo ""
  fi
}


make_tarball() {
  frompath="$1"
  topath="$2"
  fromsize=$(du --block-size=1 --apparent-size --summarize "${frompath}" | cut -f 1)
  # every 50 blocks, set a checkpoint, each block is 10KB based on input size.
  checkpoint=$((fromsize / 10240 / 50))
  checkpointaction=$(printf 'ttyout=\b-\>')
  echo "Estimated: [==================================================]"
  echo -n "Progress:    [ "
  tar -I "pigz -p $THREADS" -c --record-size=10240 --checkpoint="${checkpoint}" --checkpoint-action="${checkpointaction}" -f "${topath}" "${frompath}"
  echo -e "\b]"
  echo -e "${GREEN}Compression Finished!${NC}"
}


compress_run() {
  local starting_dir="$PWD"
  local run_id="$1"
  local reads_dir="$2"
  # pass the vars for each of these when called.
  local -n raw_md5="$3"
  local -n raw_digest="$4"
  local -n compressed="$5"
  local -n compressed_md5="$6"

  raw_md5="${PWD}/${run_id}.files.md5"
  raw_digest="${PWD}/${run_id}.files.md5.digest"
  compressed="${PWD}/${run_id}.tar.gz"
  compressed_md5="${compressed}.md5"
  # lesgetit
  echo -e "${GREEN}Starting pre-flight checks!${NC}"
  echo -e "${YELLOW}Calculating checksums for all reads in $reads_dir${NC}"
  cd "$reads_dir"
  # find all the files, sort em, then hash em with xargs
  find . -type f -print0 | sort -z | xargs -0 md5sum > "$raw_md5"
  echo -e "${GREEN}checksum of files saved to${NC} $raw_md5"
  # hash digest
  echo "creating digest"
  md5sum "$raw_md5" > "$raw_digest"
  echo -e "${GREEN}Digest saved to${NC} $raw_digest"
  # make the big tarball
  echo -e "${YELLOW}Compressing files! Please stand by!${NC}"
  # move up one directory so we can compress the bam_pass dir.
  cd ..
  make_tarball "$(basename "$reads_dir")" "$compressed"
  cd "$starting_dir" # back to /data/runs
  echo -e "${YELLOW}Hashing tarball... please stand by${NC}"
  md5sum "$compressed" > "$compressed_md5"
}

choose_bucket() {
  local var_name="$1"
  shift
  local -n workspaces_ref="$1"
  local -n paths_ref="$2"

  echo "Select a terra workspace to upload this run into:"
  local i=1
  for ((i = 0; i < ${#workspaces_ref[@]}; i++)); do echo -e "  $((i+1))) ${YELLOW}${workspaces_ref[$i]}${NC}\n     ${paths_ref[$i]}"; done
  local choice
  while true; do
    read -r -p "enter the number for the desired workspace [1-${#paths_ref[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#paths_ref[@]} )); then
      break
    else
      echo -e "${RED}Invalid selection! Enter a number between 1 and ${#paths_ref[@]}${NC}"
    fi
  done
  local selected="${paths_ref[$((choice-1))]}" # decrement by 1 since bash indexes by zero
  printf -v "$var_name" "%s" "$selected"
}

upload_to_bucket() {
  local dest_bucket="$1"
  shift
  local file="$2"
  local local_hash_hex="$3"
  local dest_path=""
  local local_hash_b64=""
  dest_path="${dest_bucket}/$(basename "$file")"
  local_hash_b64=$(cat "$local_hash_hex" | awk -F' ' '{print $1}' | xxd -r -p | base64)
  echo "Upload Details:"
  echo -e "${YELLOW}File:${NC}      $file"
  echo -e "${YELLOW}Dest:${NC}      $dest_path"
  echo -e "${YELLOW}Hash(hex):${NC} $local_hash_hex"
  echo -e "${YELLOW}Hash(b64):${NC} $local_hash_b64"
  echo ""
  echo -e "${YELLOW}Beginning upload... please stand by${NC}"
  gcloud storage cp "$file" "$dest_path" --content-md5="$local_hash_b64"
  echo -e "${GREEN}upload complete! Verifying remote hash...${NC}"
  remote_hash=$(gcloud storage hash "$dest_path" | grep "md5_hash" | awk -F' ' '{print $2}')
  if [[ "$local_hash_b64" == "$remote_hash" ]]; then
    echo -e "${GREEN}SUCCESS: checksums match!${NC}"
    echo -e "${YELLOW}LOCAL:${NC}   $local_hash_b64"
    echo -e "${YELLOW}REMOTE:${NC}  $remote_hash"
    echo ""
  else
    echo -e "${RED}ERROR:  checksums DO NOT match!${NC}"
    echo -e "${YELLOW}LOCAL:${NC}  $local_hash_b64"
    echo -e "${YELLOW}REMOTE:${NC} $remote_hash"
    echo ""
  fi
}


generate_input_json() {
  local run_id="$1"
  local dest_bucket="$2"
  local raw_digest="$3"
  local raw_MD5="$4"
  local run_tarball="$5"
  local run_tarball_MD5="$6"
  local samplesheet="$7"
  local summary="$8"
  local summary_MD5="$9"
  local json_out="${run_tarball%.tar.gz}_inputs.json"

  cat <<EOF | tee "$json_out"
{
  "promethION_runs_id": "$run_id",
  "RawChecksum": "${dest_bucket}/$(basename "$raw_MD5")",
  "RawDigest": "${dest_bucket}/$(basename "$raw_digest")",
  "RunChecksum": "${dest_bucket}/$(basename "$run_tarball_MD5")",
  "RunTarball": "${dest_bucket}/$(basename "$run_tarball")",
  "Samplesheet": "${dest_bucket}/$(basename "$samplesheet")",
  "SequencingSummary": "${dest_bucket}/$(basename "$summary")",
  "SummaryChecksum": "${dest_bucket}/$(basename "$summary_MD5")"
}
EOF

  echo -e "${GREEN}Wrote Demux input json to $json_out${NC}"
}

# init empty variables so we can set them with our namerefs below
READS_DIR=""
SUMMARY=""
SUMMARY_MD5=""
SAMPLESHEET=""
RAW_MD5=""
RAW_DIGEST=""
TARBALL=""
TARBALL_MD5=""

#-- main execution ------------------------------------------------------------#
[[ $# -eq 0 ]] && usage # if no args, display usage and exit 1

# todo: add conditional check for bad args (too many)
RUN="$1"

# select which workspace we want to upload this run into
choose_bucket DEST_BUCKET WORKSPACES BUCKET_PATHS

# locate our files.
find_files "$RUN" READS_DIR SUMMARY SUMMARY_MD5 "$READS_FORMAT"

# check for samplesheet in bucket
find_samplesheet "$DEST_BUCKET" "$RUN" SAMPLESHEET

# hash the sequencing summary
echo -e "${YELLOW}Hashing sequencing summary:${NC} $SUMMARY"
md5sum "$SUMMARY" > "$SUMMARY_MD5"

# hash 'n compress the reads
compress_run "$RUN" "$READS_DIR" RAW_MD5 RAW_DIGEST TARBALL TARBALL_MD5

# upload everything to the bucket.
upload_to_bucket "$DEST_BUCKET" "$SUMMARY" "$SUMMARY_MD5"
upload_to_bucket "$DEST_BUCKET" "$RAW_MD5" "$RAW_DIGEST"
upload_to_bucket "$DEST_BUCKET" "$TARBALL" "$TARBALL_MD5"

# spit out the json for input into the runs datatable
generate_input_json "$RUN" "$DEST_BUCKET" "$RAW_DIGEST" "$RAW_MD5" "$TARBALL" "$TARBALL_MD5" "$SAMPLESHEET" "$SUMMARY" "$SUMMARY_MD5"

echo -e "${GREEN}Finished! Have a wonderful day!${NC}"
exit 0
