#!/bin/bash
# design notes:
#  builder has all buildpack installed
#  builder acquire lock on nfs 

# all envs
# REG_URL=docker://registry.internal/
# CFSTACK_TAG=latest
# CFSTACK_LIB=
# CF_STACK=cflinuxfs2
# PREDEFINED_BP=
# BP_DIR=/var/lib/buildpacks
# BP_CACHE_DIR=/mnt/cache
#detect buildpack

if [ -z "$APP_DEST" ]
then
    echo APP_DEST not specified, exiting
fi
if [ -z "$APP_IMG" ]
then
    echo APP_IMG not specified, exiting
fi

export CF_STACK=${CF_STACK:-cflinuxfs2}
export CFSTACK_URL="${REG_URL:-docker://registry.internal/}${CFSTACK_LIB}${CF_STACK}:${CFSTACK_TAG:-latest}"
export APP_DEST_URL="${REG_URL:-docker://registry.internal/}${APP_DEST}"
export APP_REG_URL="${REG_URL:-docker://registry.internal/}${APP_IMG}"


bp_dir=${BP_DIR:-/var/lib/buildpacks}

APP_TMPDIR=`mktemp -d`
bp_cache_dir=${BP_CACHE_DIR:-/mnt/cache}
mkdir -p $bp_cache_dir/0 

fetch_app_objs () {
    # $1 APP_REG_URL
    # $2 APP_TMPDIR
    TMPFILE=`mktemp `
    skopeo copy --additional-tag ${1/docker:\/\//} --src-tls-verify=false --src-creds jose:hola $1 docker-archive:$TMPFILE
    #FIXME: creds
    cat $TMPFILE|undocker -o $2
    rm $TMPFILE
}

build_on_cache () {
    # $1 detected_bp
    # $2 APP_TMPDIR
    # $3 cache_dir
    bp_name=`basename $1`
    t_cache_dir=$3/$bp_name
    mkdir -p $t_cache_dir
    CF_STACK=cflinuxfs2 builder -buildArtifactsCacheDir $t_cache_dir -buildpacksDir /var/lib/buildpacks -buildpackOrder python-buildpack,staticfile -buildDir $APP_TMPDIR
    t_droplet_dir=`mktemp -d`
    tar xzf /tmp/droplet -C $t_droplet_dir
    APP_DROPLET_DIR=$t_droplet_dir CF_STACK=cflinuxfs2 erb /usr/local/share/bp-build/entry.erb > /tmp/entry.sh
    chmod +x /tmp/entry.sh
    #push_image $APP_TMPDIR
    skopeo copy --src-tls-verify=false --src-creds jose:hola $CFSTACK_URL oci:/tmp/cfstack:latest
    umoci insert --image /tmp/cfstack:latest $t_droplet_dir /home/vcap/
    umoci insert --image /tmp/cfstack:latest /tmp/entry.sh /home/vcap/entry.sh
    skopeo copy --dest-tls-verify=false --dest-creds jose:hola oci:/tmp/cfstack:latest $APP_DEST_URL 

}

fetch_app_objs "$APP_REG_URL" $APP_TMPDIR

detected_bp=${PREDEFINED_BP}

if [ -z "${detected_bp}" ]
   then
       for bp in $bp_dir/*
       do
	   if $bp/bin/detect $APP_TMPDIR; then
	       detected_bp=$bp
	       break
	   fi
       done
fi
if [ ! -d "$detected_bp" ]
then
    echo buildpack $detected_bp does not exist
    exit 0
fi

## lock_on_bp_cache_dir
while true
do
    for d in $bp_cache_dir/*;do
	if [ -d $d ]
	then
	    if (
		flock -w 1 9 || exit 1
		build_on_cache $detected_bp $APP_TMPDIR $d
		true
	    ) 9>$d/bp_lock
	    then
		exit 0
	    fi
	fi
    done
done

