#!/usr/bin/env bash
# shellcheck shell=bash
#   ___  __  _  ___ __  _  
#  | _ \/__\| |/ / |  \| |
#  | v / \/ |   <| | | ' |
#  |_|_\\__/|_|\_\_|_|\__|
#
# @name         : g2g
# @version      : 1.0.0
# @date         : 12/02/2022
# @description  : Gitea to Github : Simple Gitea hook / service who mirroring all your Gitea repo to Github (with git push --mirror).
# @author       : Rokin  
# @contact      : git@rokin.in
# @website      : https://git.rokin.in
#
# @install : (Tested on Alpine-Linux with Gitea server)
#                > apk add bash jq curl
#                > dst='/usr/bin/g2g' ; > $dst && chmod 755 $dst && vi $dst
#                > g2g service install
#
# @uninstall :
#                > g2g hook uninstall && g2g service uninstall && rm -f /usr/bin/g2g
#
##


#============================================
# Config :                                  #
#============================================

# Enable console messages ? : "true/false".
DEBUG="true"

# Gitea local root path repository.
GITEA_SERVER_ROOT='/var/lib/gitea/git'

GITEA_SERVER_USER='gitea'
GITEA_SERVER_GROUP='www-data'

# Gitea user credential 
GITEA_USERNAME=''
GITEA_TOKEN=''
GITEA_BASEURL="https://YOURGITEA.XYZ/api/v1/repos"

# Github user credential 
GITHUB_USERNAME=''
GITHUB_TOKEN=''
GITHUB_BASEURL="https://api.github.com/repos/${GITHUB_USERNAME}"




#============================================
# Base fuctions :                           #
#============================================

e='echo -en'; E='echo -e'
msg() { [ "$DEBUG" == "true" ] && $E "  > $1"; }
bye() { $E '***************************' && $E '' && exit 0 ; }
strip() { $e "${1//\"/}";}

gitea_get() {
    raw=$($e "$gitea_raw" | jq ".data[0].${1}") # data[] for all entry.
    $e "$(strip "$raw")"
}

github_get() {
    raw=$($e "$github_raw" | jq ".${1}")
    $e "$(strip "$raw")"
}

github_create() {  
    # https://docs.github.com/en/rest/reference/repos#create-a-repository-for-the-authenticated-user
    curl -s -S -X POST -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/user/repos" \
    -d "{ 
        \"name\": \"${gitea_name}\", 
        \"description\": \"${gitea_description} > Mirror of ${gitea_html_url}\", 
        \"homepage\": \"${gitea_html_url}\",
        \"private\": ${gitea_private},
        \"has_issues\": true,
        \"has_projects\": false,
        \"has_wiki\": false,
        \"auto_init\": false
        }" > /dev/null
}

github_update() {  
    # https://docs.github.com/en/rest/reference/repos#update-a-repository
    curl -s -S -X PATCH -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" "${GITHUB_BASEURL}/${gitea_name}" \
    -d "{ 
        \"name\": \"${gitea_name}\", 
        \"description\": \"${gitea_description} > Mirror of ${gitea_html_url}\", 
        \"homepage\": \"${gitea_html_url}\",
        \"private\": ${gitea_private}
        }" > /dev/null
}

github_push() {
    _root="${GITEA_SERVER_ROOT}/${GITEA_USERNAME,,}/${gitea_name}.git"
    if [[ ! "${PWD}" == "${_root}" ]]; then
        cd "${_root}" || exit 0
    fi
    git push --mirror "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${gitea_name}.git"
}


#============================================
# Hook :                                    #
#============================================

hook() { 
    # Install hooks
    if [[ "${1}" == "install" ]]; then
        dir_list=$(ls -d ${GITEA_SERVER_ROOT}/${GITEA_USERNAME,,}/*/)
        for repo in $dir_list; do 
            if [[ ! "$repo" = *.wiki.git* ]]; then # we dont want the wiki dir.
                ddir="${repo}hooks/post-receive.d"
                if [[ -d "${ddir}" ]]; then
                    _file="${ddir}/github_mirror"
                    hook_raw "${_file}"
                    chown ${GITEA_SERVER_USER}:${GITEA_SERVER_GROUP} "${_file}"
                    chmod 755 "${_file}"
                fi
            fi
        done
        return 0
    fi
    # Uninstall hooks
    if [[ "${1}" == "uninstall" ]]; then
        dir_list=$(ls -d ${GITEA_SERVER_ROOT}/${GITEA_USERNAME,,}/*/)
        for repo in $dir_list; do 
            ddir="${repo}hooks/post-receive.d"
            if [[ -d "${ddir}" ]]; then
                rm -f "${ddir}/github_mirror"
            fi
        done
    fi
    return 0
}

hook_raw() { 
sc="${1}"
cat > "${sc}" <<-'EOF'
#!/usr/bin/env bash
command -v g2g >/dev/null 2>&1 || { exit 0; }
name=$(basename "$PWD")
name=${name%.git}
#echo "*** Script executed from: ${PWD}" >&2
#echo "*** Script location: $(dirname $0)" >&2
if [[ -n "$name" ]]; then
    g2g mirror "${name,,}" 2>&1
fi
EOF
}


#============================================
# Service :                                 #
#============================================

service() { 
    # Install service
    if [[ "${1}" == "install" ]]; then
        service_raw_inst "/etc/periodic/15min/github_mirror_deploy"
        service_raw_mirror "/etc/periodic/15min/github_mirror_sync"
        return 0
    fi

    # Uninstall service
    if [[ "${1}" == "uninstall" ]]; then
        rm -f "/etc/periodic/15min/github_mirror_deploy"
        rm -f "/etc/periodic/15min/github_mirror_sync"
        return 0
    fi
}

# Deploy hook on repo.
service_raw_inst() { 
sc="$1"
cat > "${sc}" << 'EOF'
#!/usr/bin/env bash
command -v g2g >/dev/null 2>&1 || { exit 0; }
g2g hook install 2>&1
EOF
chown root:root "${sc}"
chmod 755 "${sc}"
}

# Sync repo each 15min.
service_raw_mirror() { 
sc="$1"
cat > "${sc}" << 'EOF'
#!/usr/bin/env bash
command -v g2g >/dev/null 2>&1 || { exit 0; }

key='GITEA_USERNAME='
v=$(grep "${key}" "$(command -v g2g)" | head -n1)
v=${v//$key/''} && v=${v//\"/} && usr=${v//\'/}

key='GITEA_SERVER_ROOT='
v=$(grep "${key}" "$(command -v g2g)" | head -n1)
v=${v//$key/''} && v=${v//\"/} && gpath=${v//\'/}

gpath=$(ls -d ${gpath}/${usr,,}/*/)
for repo in $gpath; do 
    if [[ ! "$repo" = *.wiki.git* ]]; then 
        repo="${repo%.git\/}"
        g2g mirror "${repo##*/}" 2>&1
    fi
done
EOF
chown root:root "${sc}"
chmod 755 "${sc}"
}

#============================================
# Mirror :                                  #
#============================================

mirror() {
    $E ''
    $E '***************************'
    $E '*   Gitea 2 Github Hook   *'
    $E '***************************'

    name="${1,,}"

    # Get Gitea values for the repo <name> (API).
    gitea_raw=$(curl --silent "${GITEA_BASEURL}/search?q=${name}&private=true&token=${GITEA_TOKEN}" -H 'accept: application/json')
    gitea_name=$(gitea_get "name")
    gitea_name="${gitea_name,,}"

    msg "name        : ${gitea_name}"

    # IF gitea_name not empty AND gitea_name == name.
    if [[ -n "$gitea_name" && "$gitea_name" == "$name" ]]; then

        gitea_description=$(gitea_get "description")
        gitea_html_url=$(gitea_get "html_url")
        gitea_private=$(gitea_get "private")
        gitea_mirror=$(gitea_get "mirror")
        gitea_fork=$(gitea_get "fork")

        # We do not want copy Gitea mirror(s) or fork(s) to Github.
        if [[ "$gitea_mirror" == "true" || "$gitea_fork" == "true" ]]; then
            msg "INFO : Abord clonning (source is a mirror or a fork)"
            bye
        fi

        # debug
        msg "description : ${gitea_description}"
        msg "url         : ${gitea_html_url}"
        msg "private     : ${gitea_private}"
        msg "mirror      : ${gitea_mirror}"
        msg "fork        : ${gitea_fork}"

        #
        # GITHUB
        # (https://docs.github.com/en/rest/reference/repos#get-a-repository--code-samples)
        #

        # Get Github values for the repo <name> (API).
        github_raw=$(curl --silent -H "Authorization: token ${GITHUB_TOKEN}" "${GITHUB_BASEURL}/${gitea_name}")
        gh_status=$(github_get "message")

        if [[ "$gh_status" == "Bad credentials" ]]; then
            msg " ERROR ! : Github : Bad credentials."
            bye
        fi

        if [[ "$gh_status" == "Not Found" ]]; then
            msg "Github repo not found: Initialized Creation"
            github_create
            github_push
            bye
        fi

        if [[ "$gh_status" == "null" ]]; then  #TODO update desc/private
            msg "Github repo found: Pushing Updates"
            github_update
            github_push
        fi
        bye
    fi
    msg "WARNING !   : Gitea repo not found ! (bad name ?)"
    bye
}


#============================================
# Init :                                    #
#============================================

_help() {
    $E && $E 'g2g Help :'
    msg 'g2g mirror  <repo name>          : Called by Gitea hooks for mirrorig repo.'
    msg 'g2g hook    <install/uninstall>  : Install/Uninstall githook on every repo founds at <conf:PATH>'
    msg 'g2g service <install/uninstall>  : Install cron service.'
    $E
}

case ${1} in
    'mirror')     mirror "${2}"  ;;
    'hook')       hook "${2}"    ;;
    'service')    service "${2}" ;;
    'help')       _help          ;;
    *)            _help          ;;
esac

exit 0
