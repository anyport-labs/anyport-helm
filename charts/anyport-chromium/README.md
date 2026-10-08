# anyport-chromium

The chart behind the **Headless browser** entry in Anyport's managed-services catalog. Users never
run this themselves — `InstallPlugin` provisions it through a `HelmApp` and the console renders
the one choice (size) that maps onto its values.

Apps drive it over the Chrome DevTools Protocol with the client they already use:

| Client | Connect with |
| --- | --- |
| Puppeteer | `puppeteer.connect({ browserURL: process.env.BROWSER_URL })` |
| Playwright | `chromium.connectOverCDP(process.env.BROWSER_URL)` |
| chromedp | `chromedp.NewRemoteAllocator(ctx, os.Getenv("BROWSER_URL"))` |

There is no fixed WebSocket endpoint to hand out: the browser's id changes on every start, so
clients take the HTTP URL and read `webSocketDebuggerUrl` from `/json/version` themselves.

## Why a first-party chart

The browser-as-a-service images most guides point at are SSPL, which the catalog refuses. What
is left is a bare browser image, and a bare Chromium does not work as a Kubernetes service on its
own — see the proxy below. The console also pushes flat `--set` scalars, which this chart's value
shape is designed for.

## The proxy, and why it is there

Chromium refuses every DevTools request — the HTTP `/json` endpoints and the WebSocket upgrade
alike — whose `Host` header is not an IP address or `localhost`:

```
Host header is specified and is not an IP address or localhost.
```

That is every client connecting by Service name. There is no flag to turn the check off. So the
browser listens on loopback only, and an nginx container in the same pod (the `proxy` values)
forwards to it with `Host: 127.0.0.1:9223`. The browser writes that address into the WebSocket
URLs it returns, so the proxy rewrites them back to the `Host` the client sent; a client that
follows `webSocketDebuggerUrl` comes back through the proxy. Idle connections are kept for
`proxy.idleTimeout` (24h) rather than nginx's 60s, because a CDP connection is silent whenever the
app is not driving the browser.

The browser's `Origin` check is left as it is: a request carrying an `Origin` (that is, one made
from a web page) is refused with 403. Server-side clients send none.

Verified against `chromedp/headless-shell:156.0.8078.12` and `nginx-unprivileged:1.30-alpine`,
both as uid 1000 on read-only root filesystems with every capability dropped: Puppeteer
(`browserURL` and `browserWSEndpoint`), Playwright `connectOverCDP` and chromedp's remote
allocator, all by hostname, loading a page and producing a screenshot and a PDF.

## No authentication, on purpose

The DevTools Protocol has none — whoever can open the port owns the browser. The boundary is the
project namespace's NetworkPolicy baseline (docs/network-isolation), under which nothing outside
the project can open a connection to it. The catalog entry therefore mints no credential and
offers no domain or public port.

The browser can fetch anything the namespace can reach: the internet, and the project's other
services. That is what the user is installing it for, and also why it must never be exposed.

## Stateless, on purpose

Each start is a fresh throwaway profile in an `emptyDir` at `/tmp`: no cookies, cache or
downloads survive a restart, and nothing needs a volume. `replicaCount` exists so the platform
can pause the service by scaling to zero, and is read as-is so that 0 is honoured. One replica
only: a CDP session belongs to the browser that created its pages.

Memory is the knob. `/dev/shm` is a memory-backed volume sized to the memory limit, because the
container runtime's 64Mi default crashes renderers on ordinary pages. Pages a client opens and
never closes stay open after it disconnects and hold their memory until the pod restarts.

## Known limits

- Fonts are DejaVu only (what the image ships): Latin, Greek, Cyrillic, Arabic and Hebrew render;
  Chinese, Japanese, Korean and emoji render as empty boxes.
- Chromium's own sandbox is off (`--no-sandbox`); it needs privileges this pod does not grant.
  The pod's security context is the isolation instead.
- The proxy listens on IPv4.

## Values that matter

| Value | Default | Notes |
| --- | --- | --- |
| `image.tag` | `156.0.8078.12` | Exact Chromium release; moves with chart releases |
| `resources` | 1Gi / 250m–1 CPU | The catalog's size presets set these (`plugins/chromium.go`) |
| `proxy.idleTimeout` | `24h` | How long an idle CDP connection is kept open |
| `service.port` | `9222` | The proxy's port; the browser itself is on `debuggingPort`, loopback only |

## Releasing

Published to `oci://ghcr.io/anyport-labs/anyport-chromium` by the release workflow, in lockstep
with the agent chart, which also rewrites `chromiumChartVersion` in `plugins/chromium.go`. Never
edit an already-published version in place.
