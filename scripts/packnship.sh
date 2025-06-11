#!/usr/bin/env bash
# Michael J. Foster
# github.com/mjfos2r

# script to compress, hash, and upload a run to the specified gcloud bucket.
# data will be hashed with md5 and compressed via tar and pigz, and then
# a json with bucket paths will be output to the terminal!

set -euo pipefail
shopt -s nullglob

# -- CONFIGURATION ------------------------------------------------------------#
READS_FORMAT="bam" #"fastq" #TODO: add opt to getopts that will allow for switching which reads it looks for, default to fastq.
THREADS="${PIGZ_THREADS:-18}" # floor it to 20 with export PIGZ_THREADS=20
WORKSPACES=(
  "mgb-Lemieux_Lab_Sequencing"
  "mgb-Lemieux-Borrelia_Genomics"
)
BUCKET_PATHS=(
  "gs://fc-secure-83a5cea5-a13e-43ab-95d3-d39955cb7e61/nanopore/promethion_runs"
  "gs://fc-9fb3817f-94b5-4992-a2e2-38856fac5b30/ONT_data/promethion_runs/"
)
# -----------------------------------------------------------------------------#

# Colors for output
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; PURPLE='\033[1;35m'; WHITE='\033[0;37m'; NC='\033[0m'

# -- Functions ----------------------------------------------------------------#
usage() { echo "Usage: $(basename ${0}) [--resume] <run_dir>"; exit 1; }

print_divider() {
  local color="$1"
  printf "${color}%*s${NC}" "$(tput cols)" | tr ' ' '-'
}


choose_bucket() {
  local var_name="$1"
  shift
  local -n workspaces_ref="$1"
  local -n paths_ref="$2"
  print_divider "$YELLOW"
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
  print_divider "$YELLOW"
}


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
    print_divider "$GREEN"
  else
    print_divider "$YELLOW"
    echo -e "${RED}!!!!${NC}"
    echo -e "${YELLOW}WARNING: Please upload the samplesheet to the bucket before demultiplexing!${NC}"
    echo "Expected path:     $samplesheet"
    echo "Expected filename: ${run_id}.csv"
    echo -e "${RED}!!!!${NC}"
    print_divider "$YELLOW"
  fi
}


make_tarball() {
  frompath="$1"
  topath="$2"
  tar -P -cf - "${frompath}" | pv -s "$(du -sb "$frompath" | awk '{print $1}')" | pigz -p "$THREADS" >"$topath"
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
  echo -e "${YELLOW}creating digest${NC}"
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
  echo -e "${GREEN}Hash saved to:${NC} $compressed_md5"
  print_divider "$WHITE"
}


upload_to_bucket() {
  local dest_bucket="$1"
  local file="$2"
  local local_hash_file="$3"
  local local_hash_hex=""
  local dest_path=""
  local local_hash_b64=""
  dest_path="${dest_bucket}/$(basename "$file")"
  local_hash_hex=$(cat "$local_hash_file" | awk -F' ' '{print $1}')
  local_hash_b64=$(echo "$local_hash_hex" | xxd -r -p | base64)
  print_divider "$WHITE"
  echo "Upload Details:"
  echo -e "${YELLOW}File:${NC}       $file"
  echo -e "${YELLOW}Dest:${NC}       $dest_path"
  echo -e "${YELLOW}Hash(file):${NC} $local_hash_file"
  echo -e "${YELLOW}Hash(hex): ${NC} $local_hash_hex"
  echo -e "${YELLOW}Hash(b64): ${NC} $local_hash_b64"
  echo ""
  echo -e "${YELLOW}Beginning upload... please stand by${NC}"
  gcloud storage cp "$file" "$dest_path" --content-md5="$local_hash_b64"
  echo -e "\n${GREEN}SUCCESS: Upload complete!${NC}\n${YELLOW}Verifying remote hash...${NC}"
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
  echo -e "${YELLOW}Uploading hash to bucket. Please stand by...${NC}"
  gcloud storage cp "$local_hash_file" "${dest_bucket}/$(basename "$local_hash_file")"
  echo -e "${GREEN}Hash upload complete!${NC}"
  print_divider "$WHITE"
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
  "Samplesheet": "${dest_bucket%/*}/samplesheets/$(basename "$samplesheet")",
  "SequencingSummary": "${dest_bucket}/$(basename "$summary")",
  "SummaryChecksum": "${dest_bucket}/$(basename "$summary_MD5")"
}
EOF

  echo -e "${GREEN}Wrote Demux input json to $json_out${NC}"
}


generate_input_tsv() {
  local run_id="$1"
  local dest_bucket="$2"
  local raw_digest="$3"
  local raw_MD5="$4"
  local run_tarball="$5"
  local run_tarball_MD5="$6"
  local samplesheet="$7"
  local summary="$8"
  local summary_MD5="$9"

  local tsv_out="${run_tarball%.tar.gz}_inputs.tsv"
  echo ""
  echo "Input TSV for DataTable:"
  cat <<EOF | tee "$tsv_out"
entity:promethION_runs_id	RawChecksum	RawDigest	RunChecksum	RunTarball	Samplesheet	summary_files	summary_checksums
"$run_id"	"${dest_bucket}/$(basename "$raw_MD5")"	"${dest_bucket}/$(basename "$raw_digest")"	"${dest_bucket}/$(basename "$run_tarball_MD5")"	"${dest_bucket}/$(basename "$run_tarball")"	"${dest_bucket%/*}/samplesheets/$(basename "$samplesheet")"	["${dest_bucket}/$(basename "$summary")"]	["${dest_bucket}/$(basename "$summary_MD5")"]
EOF
  echo ""
  echo -e "${GREEN}Wrote Demux input TSV to ${tsv_out}${NC}"
}

# init empty variables so we can set them with our namerefs below
DEST_BUCKET=""
READS_DIR=""
SUMMARY=""
SUMMARY_MD5=""
SAMPLESHEET=""
RAW_MD5=""
RAW_DIGEST=""
TARBALL=""
TARBALL_MD5=""

RESUME=false

#-- main execution ------------------------------------------------------------#
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      RESUME=true
      shift
      ;;
    -*)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      usage
      ;;
    *)
      RUN="${1%/}"
      shift
      ;;
  esac
done

[[ -z "${RUN:-}" ]] && usage # if run isn't set, show usage and dip.

# clear the terminal screen for execution.
clear

# select which workspace we want to upload this run into
choose_bucket DEST_BUCKET WORKSPACES BUCKET_PATHS

# and set up the path to upload all of the files to within the bucket.
DEST_BUCKET_PATH="${DEST_BUCKET}"/"${RUN}"

# locate our files.
find_files "$RUN" READS_DIR SUMMARY SUMMARY_MD5 "$READS_FORMAT"

# check for samplesheet in bucket
find_samplesheet "$DEST_BUCKET" "$RUN" SAMPLESHEET

# Check for existence of hashes and recompress it all if a single one is missing.
if $RESUME; then
  RAW_MD5="${PWD}/${RUN}.files.md5"
  RAW_DIGEST="${PWD}/${RUN}.files.md5.digest"
  TARBALL="${PWD}/${RUN}.tar.gz"
  TARBALL_MD5="${PWD}/${RUN}.tar.gz.md5"
fi

if $RESUME && [[ -s "$RAW_MD5" && -s "$RAW_DIGEST" && -s "$TARBALL" && -s "$TARBALL_MD5" && -s "$SUMMARY_MD5" ]]; then
    echo -e "${YELLOW}Resume mode: Found existing tarball and relevant hashes. skipping compression and all hashing.${NC}"
    print_divider "$YELLOW"
else
  # hash the sequencing summary
  echo -e "${YELLOW}Hashing sequencing summary:${NC} $SUMMARY"
  cd "$(dirname "$SUMMARY")"
  md5sum "$(basename "$SUMMARY")" > "/data/runs/$SUMMARY_MD5"
  cd - && echo -e "${GREEN}Sequencing Summary hash saved to: ${PWD}/${SUMMARY_MD5}${NC}"
  print_divider "$YELLOW"
  # hash 'n compress the reads
  compress_run "$RUN" "$READS_DIR" RAW_MD5 RAW_DIGEST TARBALL TARBALL_MD5
fi

# upload everything to the bucket.
upload_to_bucket "$DEST_BUCKET_PATH" "$SUMMARY" "$SUMMARY_MD5"
upload_to_bucket "$DEST_BUCKET_PATH" "$RAW_MD5" "$RAW_DIGEST"
upload_to_bucket "$DEST_BUCKET_PATH" "$TARBALL" "$TARBALL_MD5"

# spit out the json (because its already made) even though DataTables only accept tsv
generate_input_json "$RUN" "$DEST_BUCKET_PATH" "$RAW_DIGEST" "$RAW_MD5" "$TARBALL" "$TARBALL_MD5" "$SAMPLESHEET" "$SUMMARY" "$SUMMARY_MD5"
generate_input_tsv "$RUN" "$DEST_BUCKET_PATH" "$RAW_DIGEST" "$RAW_MD5" "$TARBALL" "$TARBALL_MD5" "$SAMPLESHEET" "$SUMMARY" "$SUMMARY_MD5"

echo -e "${GREEN}Finished! Have a wonderful day!${NC}"
print_divider "$GREEN"
exit 0
