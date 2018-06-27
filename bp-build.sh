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
# NO_DROP_ROOT
#detect buildpack

if [ -f /etc/reg-authfile/.dockerconfigjson ]
then
    echo No secret file defined for docker registry, exiting
    cat <<EOF
Add a volume mount for registry's credentials as 
        volumeMounts:
        - name: regsecs
          mountPath: /etc/reg-authfile
and also define a volume:
      volumes:
      - name: regsecs
        secret:
          secretName: regcred
EOF
fi

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

if [ -n "$BP_NO_DETECT" ] && [ -z "$BP_LIST" ]
then
    cat <<EOF
Must set BP_LIST WHEN set BP_NO_DETECT
EOF
    exit 1
fi

bp_list_installed=`cat "$bp_dir"/buildpacks.lst |sort -r -n -t : -k2,1|cut -d : -f 1|tr '\n' ','|sed 's/,$//'`
bp_list=${BP_LIST:-$bp_list_installed}

APP_TMPDIR=`mktemp -d`
bp_cache_dir=${BP_CACHE_DIR:-/mnt/cache}
mkdir -p $bp_cache_dir/0 

fetch_app_objs () {
    # $1 APP_REG_URL
    # $2 APP_TMPDIR
    TMPFILE=`mktemp `
    skopeo copy --authfile /etc/reg-authfile/.dockerconfigjson --additional-tag ${1/docker:\/\//} --src-tls-verify=false $1 docker-archive:$TMPFILE
    #FIXME: creds
    cat $TMPFILE|undocker -o $2
    rm $TMPFILE
}

build_on_cache () {
    # $1 detected_bp
    # $2 APP_TMPDIR
    # $3 cache_dir
    set -e
    bp_name=`basename $1`
    t_cache_dir=$3/$bp_name
    mkdir -p $t_cache_dir
    CF_STACK=cflinuxfs2 builder -buildArtifactsCacheDir $t_cache_dir -buildpacksDir /var/lib/buildpacks -buildpackOrder "$bp_list" -buildDir $APP_TMPDIR "${BP_NO_DETECT:+-skipDetect}"
    t_droplet_dir=`mktemp -d`
    tar xzf /tmp/droplet -C $t_droplet_dir || exit 0
    APP_DROPLET_DIR=$t_droplet_dir CF_STACK=cflinuxfs2 erb /usr/local/share/bp-build/entry.erb > /tmp/entry.sh
    chmod +x /tmp/entry.sh
    #push_image $APP_TMPDIR
    skopeo copy --authfile /etc/reg-authfile/.dockerconfigjson --src-tls-verify=false $CFSTACK_URL oci:/tmp/cfstack:latest
    umoci insert --image /tmp/cfstack:latest $t_droplet_dir /home/vcap/
    umoci insert --image /tmp/cfstack:latest /tmp/entry.sh /home/vcap/entry.sh
    if [ -z "$NO_DROP_ROOT" ]; then
	umoci config --config.user "vcap:vcap" --image /tmp/cfstack:latest
    fi
    skopeo copy --authfile /etc/reg-authfile/.dockerconfigjson --dest-tls-verify=false oci:/tmp/cfstack:latest $APP_DEST_URL 

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

