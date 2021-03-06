#!/bin/bash

# Note: Collabora repository with pending patches
# https://git.collabora.com/cgit/linux.git/log/?h=topic/chromeos/waiting-for-upstream

chromeos_path=$(python -c "from config import chromeos_path; print chromeos_path;")
chromeos_repo=$(python -c  "from config import chromeos_repo; print chromeos_repo;")

stable_path=$(python -c "from config import stable_path; print stable_path;")
stable_repo=$(python -c  "from config import stable_repo; print stable_repo;")

upstream_path=$(python -c "from common import upstream_path; print upstream_path;")
if [[ "$(dirname ${upstream_path})" = "." ]]; then
	# Needs to be an absolute path name
	upstream_path="$(pwd)/${upstream_path}"
fi
upstream_repo=$(python -c  "from config import upstream_repo; print upstream_repo;")

next_path=$(python -c "from config import next_path; print next_path;")
if [[ "$(dirname ${next_path})" = "." ]]; then
	# Needs to be an absolute path name
	next_path="$(pwd)/${next_path}"
fi
next_repo=$(python -c  "from config import next_repo; print next_repo;")

rebase_baseline_branch=$(python -c "from config import rebase_baseline_branch; print rebase_baseline_branch;")

android_repo=$(python -c  "from config import android_repo; print android_repo;")
if [[ "${android_repo}" != "None" ]]; then
    android_baseline_branch=$(python -c "from config import android_baseline_branch; print android_baseline_branch;")
    android_path=$(python -c "from config import android_path; print android_path;")
fi

upstreamdb=$(python -c "from common import upstreamdb; print upstreamdb;")
nextdb=$(python -c "from common import nextdb; print nextdb;")
rebasedb=$(python -c "from config import rebasedb; print rebasedb;")

usage()
{
    echo "Usage: $0 [-f]"
    exit 1
}

use_force=0
verbose=0

while getopts fv opt
do
    case ${opt} in
    f)	use_force=1;;
    v)	verbose=1;;
    *)	usage;;
    esac
done

shift $((OPTIND - 1))

# Simple clone:
# Clone repository, do not add 'upstream' remote
clone_simple()
{
    local destdir=$1
    local repository=$2
    local force=$3

    echo "Cloning ${repository} into ${destdir}"

    if [[ -d "${destdir}" ]]; then
	pushd "${destdir}" >/dev/null
	git checkout master
	if [[ -n "${force}" ]]; then
	    # This is needed if the origin may have been rebased
	    git fetch origin
	    git reset --hard origin/master
	else
	    git pull
	fi
	popd >/dev/null
    else
	git clone "${repository}" "${destdir}"
    fi
}

clone_simple "${upstream_path}" "${upstream_repo}"

if [[ "${stable_repo}" != "None" ]]; then
    clone_simple "${stable_path}" "${stable_repo}"
fi

# Complex clone:
# Clone repository, check out branch, add 'upstream' remote
# Also, optionally, add 'next' remote
clone_complex()
{
    local destdir=$1
    local repository=$2
    local branch=$3

    echo "Cloning ${repository}:${branch} into ${destdir}"

    if [[ -d "${destdir}" ]]; then
	pushd "${destdir}" >/dev/null
	git reset --hard HEAD
	git fetch origin
	if git rev-parse --verify "${branch}" >/dev/null 2>&1; then
		git checkout "${branch}"
		if ! git pull; then
		    # git pull may fail if the remote repository was rebased.
		    # Pull it the hard way.
		    git reset --hard "origin/${branch}"
		fi
	else
		git checkout -b "${branch}" "origin/${branch}"
	fi
	git remote -v | grep upstream || {
		git remote add upstream "${upstream_path}"
	}
	git fetch upstream
	if [[ "${next_repo}" != "None" ]]; then
	    git remote -v | grep next || {
		git remote add next "${next_path}"
	    }
	    git fetch next
	fi
	popd >/dev/null
    else
	git clone "${repository}" "${destdir}"
	pushd "${destdir}" >/dev/null
	git checkout -b "${branch}" "origin/${branch}"
	git remote add upstream "${upstream_path}"
	git fetch upstream
	if [[ "${next_repo}" != "None" ]]; then
	    git remote add next "${next_path}"
	    git fetch next
	fi
	popd >/dev/null
    fi
}

if [[ "${next_repo}" != "None" ]]; then
    clone_simple "${next_path}" "${next_repo}" "force"
fi

clone_complex "${chromeos_path}" "${chromeos_repo}" "${rebase_baseline_branch}"

if [[ "${android_repo}" != "None" ]]; then
    clone_complex "${android_path}" "${android_repo}" "${android_baseline_branch}"
fi

# Remove and re-create all databases (for now) except upstream database.
rm -f "${rebasedb}" "${nextdb}"

echo "Initializing database"
python initdb.py

echo "Initializing upstream database"
python initdb-upstream.py

if [[ "${next_repo}" != "None" ]]; then
    echo "Initializing next database"
    ./initdb-next.py
fi

echo "Updating rebase database with upstream commits"
python update.py

echo "Calculating initial revert list"
python revertlist.py
echo "Calculating initial drop list"
python drop.py
echo "Calculating replace list"
python upstream.py
echo "Calculating topics"
python topics.py
