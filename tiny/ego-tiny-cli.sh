#!/bin/bash
# ego-tiny: the ego-browser CLI bound to ego tiny, running the runtime built
# from this repository instead of the one embedded in the app. It never talks
# to ego lite: the server name and the SDK (which keeps its state in
# ~/.ego-tiny) are its own.
SELF="$0"
while [ -L "$SELF" ]; do SELF="$(readlink "$SELF")"; done
RES="$(cd "$(dirname "$SELF")" && pwd)"
CLI="$RES/../Frameworks/ego Framework.framework/Versions/Current/Helpers/ego-browser"
SDK="$RES/ego-tiny-sdk/index.js"

case "${1:-}" in
upgrade)
	echo "ego-tiny: upgrades are disabled; rebuild with tiny/build-tiny.sh --install" >&2
	exit 1
	;;
nodejs | skill)
	cmd="$1"
	shift
	exec "$CLI" --ego-server-name=ego-tiny "$cmd" --sdk-path "$SDK" "$@"
	;;
*)
	exec "$CLI" --ego-server-name=ego-tiny "$@"
	;;
esac
