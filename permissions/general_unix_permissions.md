# Notes on Unix permissions

Here's what I've learned re: system perms and some useful things to remember. 

## Usergroups

So in Unix, users are able to be added and removed from various usergroups. These groups allow for simplified 
management of permissions. Rather than expanding each user's permissions each time a new user is added to the server, 
we can just set group permissions and then add and remove users from that group. 

To create a new group we execute the following: 

```bash
sudo groupadd <group-name>
```

we can also list all groups on the system using: `getent group` or `cat /etc/group`. 

We can interrogate which groups a user is part of via: `groups <username>` 

We can look at all users in a specific group via: `getent group <group-name>`

***
To add users to a usergroup, we execute the following:

```bash
sudo usermod -a -G <group-name> <user-name>
```
Make sure to use the `-a` flag as it **APPENDS** the group to that user. Otherwise it will overwrite all groups with the one you just set. Don't do that. 

to remove a user from a group: `sudo gpasswd -d <user-name> <group-name>`
to delete a group: `sudo groupdel <group-name>`
to set primary group for a user: `sudo usermod -g <group-name> <user-name>`

To view your own group memberships: `groups`

*** 

## Setting permissions on directories and files

So now that we've set up a group and added users to it, let's make sure that the directory is recursively owned by the group and that we've set the groupid bit to allow for recursive permissions when new files and subdirectories are added.

updating the owner of a file to be owned by a group: 

```bash
# set owner to group
sudo chown -R :group-name /usr/local/my-dir/
# set write permissions `-R` recursively
sudo chmod -R g+w /usr/local/my-dir/
# set groupid bit (setgid) recursively to ensure all new files and dirs keep group ownership.
sudo chmod -R g+s /usr/local/my-dir/
```

and to validate this, simply use `ls -lhga /usr/local/my-dir` and it should reflect this update permissions structure, to use a systemwide installation of miniconda3 for example, this is what you should see: 

```bash
(base) mf019@ram-optimized:~$ ls -lhga /usr/local/miniconda3/
total 35M
drwxrwsr-x  19 conda-users 4.0K Feb 14 19:20 .
drwxr-xr-x  11 root        4.0K Feb 13 20:24 ..
-rw-rw-r--   1 conda-users   87 Feb 13 20:24 .condarc
-rw-rw-r--   1 conda-users  57K Feb 11 20:14 LICENSE.txt
-rwxrwxr-x   1 conda-users  34M Feb 13 20:24 _conda
drwxrwsr-x   2 conda-users 4.0K Feb 14 19:20 bin
drwxrwsr-x   2 conda-users 4.0K Feb 13 20:24 cmake
drwxrwsr-x   2 conda-users 4.0K Feb 13 20:38 compiler_compat
drwxrwsr-x   2 conda-users  20K Feb 14 19:20 conda-meta
drwxrwsr-x   2 conda-users 4.0K Feb 13 20:38 condabin
drwxrwsr-x   4 conda-users 4.0K Feb 19 16:33 envs
drwxrwsr-x   6 conda-users 4.0K Feb 14 19:20 etc
drwxrwsr-x  31 conda-users 4.0K Feb 14 19:20 include
drwxrwsr-x  17 conda-users  16K Feb 14 19:20 lib
drwxrwsr-x   4 conda-users 4.0K Feb 13 20:24 man
drwxrwsr-x 432 conda-users  56K Feb 19 16:07 pkgs
drwxrwsr-x   2 conda-users 4.0K Feb 13 20:24 sbin
drwxrwsr-x  19 conda-users 4.0K Feb 14 19:20 share
drwxrwsr-x   3 conda-users 4.0K Feb 13 20:24 shell
drwxrwsr-x   4 conda-users 4.0K Feb 13 20:38 ssl
-rwxrwxr-x   1 conda-users  411 Feb 11 20:14 uninstall.sh
drwxrwsr-x   3 conda-users 4.0K Feb 13 20:24 x86_64-conda-linux-gnu
drwxrwsr-x   3 conda-users 4.0K Feb 13 20:24 x86_64-conda_cos7-linux-gnu
```

And that's all I've got for now folks. 

***

#>>{MJF - 2025-Feb-19}<<#
