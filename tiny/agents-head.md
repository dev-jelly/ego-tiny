<!-- ego-tiny:begin -->
> **This repository is ego tiny**, a personal fork of `citrolabs/ego-lite` that
> rebuilds the browser with every vendor and analytics upload removed. Read
> [`tiny/MAINTAINING.md`](tiny/MAINTAINING.md) before changing anything.
>
> - Everything this fork adds lives in `tiny/`. Do not edit upstream files for
>   fork purposes; upstream is merged regularly with `tiny/sync-upstream.sh`,
>   conflicts are resolved in upstream's favour, and `tiny/apply-overlay.sh`
>   re-applies the fork's layer (product rename, top-level `README.md`, this
>   block).
> - Never weaken the endpoint checks in `tiny/patch_app.py`. A build that fails
>   because an endpoint moved is the intended outcome; re-audit instead.
> - The rest of this file is upstream's guide to the runtime and still applies.
<!-- ego-tiny:end -->

