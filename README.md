# g2g

Simple Gitea hook / service who mirroring all your Gitea repo to Github (with git push --mirror). <br>
*Tested only on Alpine-Linux with Gitea server.* <br>
*The script requires bash, jq, curl, grep and git.*

<br>

This should be easily adapted to other distributions without too many modifications, it should certainly be necessary to modify the location where the cronjob is installed (/etc/periodic/15min) for Debian/Arch/... based system.

<br>

**BE VERY CAREFUL !! : <br>
If a Github repo already exists with the same name as a Gitea repo but with different content, the whole Github repository will be overwritten !**


<br>

### How the hook is triggered :

-   Every 15min, a cronjob install the hook in the repos of the configured .
-   Every 15min, a cronjob launches the synchronization of the whole repo (git push --mirror).
-   When a Gitea depo receives a push, the hook (.hooks/post-receive.d/github_mirror) is triggered and start the synchronization on Github.

### What does the script do :

-   Clone your Gitea repositories on Github.
-   Automatically create a new repository on Github if it does not exist.
-   Synchronize the description.
-   Synchronize the stat (private/public) of the repository.

### What the script doesn't do :

-   Does not manage several different accounts.
-   Do not delete any Github repo (if you delete a Gitea repo, you will have to do it manually on Github).
-   Does not synchronize anything from Github to Gitea.

*(The creation of Github repositories and the retrieval of information from Gitea repositories is done through the official API with curl).*

<br>

#### Install 
```shell
apk add bash jq curl grep
wget "https://git.rokin.in/Rokin/gitea2github/raw/branch/master/g2g.sh"
cp -f g2g.sh /usr/bin/g2g
chown root:root /usr/bin/g2g
chmod 755 /usr/bin/g2g
g2g service install
```

#### Uninstall 
```shell
g2g hook uninstall
g2g service uninstall
rm -f /usr/bin/g2g
```

#### Usage 
```shell
#Manual push (single repo): 
g2g mirror <repo_name>

#Manual push (all repo): 
/etc/periodic/15min/github_mirror_sync

```
