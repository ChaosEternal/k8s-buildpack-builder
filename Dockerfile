ARG REGISTRY=registry.internal
ARG STACK=bp-bld-umoci
ARG VERSION=latest
ARG STACK_FULL=${REGISTRY}/$STACK:$VERSION
FROM $STACK_FULL
COPY undocker/undocker.py /usr/local/bin/undocker
COPY bp-build.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/undocker  /usr/local/bin/bp-build.sh
COPY buildpacks /var/lib/buildpacks
COPY entry.erb /usr/local/share/bp-build/entry.erb
USER vcap:vcap
CMD ["bash","/usr/local/bin/bp-build.sh"]
