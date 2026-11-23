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