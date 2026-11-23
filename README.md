# QR-Code-generator-brightscript

## Introduction:

With this Library, adding a QR code to your Roku app is a simple as including this in your xml file: 

\<qrCode text="https://www.paramountplus.com/" />

That generates synchronously on whatever thread the `<qrCode>` node lives on --
normally the render thread, which is fine for a few small codes but can hitch
the UI for a large/frequent one. For that case, generate on a background Task
thread instead, from any component's own .brs (add `qrCode.cache.brs` to that
component's `<script>` tags first):

```brightscript
sub init()
    m.qrTask = qrGenerateAsync({ text: "https://www.paramountplus.com/", ecl: "HIGH" }, "onQrDone")
end sub

sub onQrDone(event as object)
    result = event.getData() ' { uri, cacheHit, error }
    if result.error = invalid then m.top.findNode("myPoster").uri = result.uri
end sub
```

Both paths call the same underlying `qrGenerateAndCache()` and share the same
`cachefs:/qrcodes/` cache, keyed on every parameter that affects the output
(text/binary, ecl, colors, border, pixel size, version range, mask) -- so a
code already generated one way is an instant cache hit the other way too. See
`components/qrCode/qrCode.cache.brs` for the full parameter list and the
reasoning behind using `cachefs:` over `tmp:` for the cache location.

## Fixes over the Paramount original

The upstream repo is archived (read-only), so these are tracked here instead.
All three were reported as issues on the original repo before it was archived
and are fixed as of this fork:

- **Large QR codes (version 7+) didn't scan** ([original report](https://github.com/paramount-engineering/QR-Code-generator-brightscript/issues/2)) —
  two off-by-one bugs in the `splice()` array helper scrambled alignment-pattern
  placement for any QR version needing 3+ alignment patterns. Versions 1-6 never
  hit this path, which is why short codes always worked. Verified against
  Project Nayuki's reference implementation across all 40 versions: 34/40
  produced wrong output before the fix, 0/40 after.
  Fix: [`4df9040`](https://github.com/yungblood/QR-Code-generator-brightscript/commit/4df90402a448759c36c39af895bb229e6f19760e).
- **Changing colors had no effect until you also changed the text** ([original report](https://github.com/paramount-engineering/QR-Code-generator-brightscript/issues/4)) —
  the old cache filename was a hash of `text` only, so re-rendering the same
  text with different colors (or border/pixel/ecl) collided with whatever PNG
  was already cached and silently served the stale image back. Fixed by
  hashing every parameter that affects the rendered pixels — see
  `qrCacheKey()` in `components/qrCode/qrCode.cache.brs`.
  Fix: [`20b2d67`](https://github.com/yungblood/QR-Code-generator-brightscript/commit/20b2d67).
- **No way to generate off the render thread** ([original report](https://github.com/paramount-engineering/QR-Code-generator-brightscript/issues/3)) —
  added `QRCodeTask` / `qrGenerateAsync()`, documented above in Introduction.
  Fix: [`20b2d67`](https://github.com/yungblood/QR-Code-generator-brightscript/commit/20b2d67).

## Author's note

I'm Kevin Hoos — I was the original developer who ported this QR code generator
library to BrightScript while working at Paramount. This fork carries forward
that work from the original at
[paramount-engineering/QR-Code-generator-brightscript](https://github.com/paramount-engineering/QR-Code-generator-brightscript).

## License

Copyright (c) 2022 Paramount (MIT License)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Attribution

This work, ["QR-Code-generator-brightscript"](https://github.com/paramount-engineering/QR-Code-generator-brightscript), is a derivative of ["QR Code generator"](https://github.com/nayuki/QR-Code-generator) by [Project Nayuki](https://www.nayuki.io/page/qr-code-generator-library), used under [MIT](https://choosealicense.com/licenses/mit/). ["QR-Code-generator-brightscript"](https://github.com/paramount-engineering/QR-Code-generator-brightscript) is licensed under [MIT](https://choosealicense.com/licenses/mit/) BY [Paramount](https://www.paramount.com).