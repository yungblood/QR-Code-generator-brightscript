'**************************************************************************************
' QR Code generator library (Brightscript) -- shared generate+cache core.
' Copyright (c) Kevin Hoos.
'
' This file is deliberately thread-agnostic: nothing in it touches a SceneGraph
' render node (Poster/Group/LayoutGroup/etc), so every function here is safe to
' call from wherever is convenient -- directly on the render/main thread for a
' quick/blocking call, or from inside a Task node's own thread for an async one.
' The only Roku objects touched are roBitmap, roFileSystem and roEVPDigest, none
' of which are SceneGraph render nodes, so none of them pay the cross-thread
' "rendezvous" cost that actual renderable nodes do -- see Roku's own Threads doc
' (https://developer.roku.com/docs/developer-program/core-concepts/threads.md)
' and the community confirmation that roBitmap creation/drawing is fine inside a
' Task thread as long as the live bitmap object itself never crosses threads.
' This code never does: it writes the finished PNG to disk and only ever hands
' the caller back a plain file-path string, which is what actually crosses the
' thread boundary (e.g. into a Task's output field) -- a plain string field set
' has no rendezvous cost.
'
' cachefs: vs tmp: -- deliberately using cachefs:, not tmp:, for the output.
' Roku's own file-system docs describe cachefs: as built for exactly this shape
' of problem (expensive to produce, safe to lose, worth persisting when there's
' room) and explicitly say cachefs: writes don't count against the app's memory
' usage. The trade-off: the OS can evict a cachefs: file at any time under
' storage pressure from other apps, unlike tmp: (which isn't auto-evicted, but
' IS wiped on every app exit, so it can never give a cache hit across restarts).
' Every read from the cache below re-checks existence immediately before use, so
' an eviction race just falls through to a normal regenerate -- never a crash or
' a stale/missing-file error surfacing to the caller.
'**************************************************************************************

' Default location for cached QR PNGs. A subfolder (not the cachefs: root) so this
' library's files are easy to spot/clear separately from anything else the host
' app caches there.
function qrCacheDir() as string
    return "cachefs:/qrcodes"
end function

' Builds a stable cache key from EVERY parameter that affects the rendered pixels,
' not just the text/binary payload. (The original renderCode() only hashed `text`,
' so two renders of the same text with different colors/border/pixel size/ecl would
' have collided on the same cache filename and silently shown the wrong image --
' fixed here by folding every parameter that can change the output into the key.)
' `p` is an associative array; only the fields actually present are hashed, so
' callers can pass just what they use.
function qrCacheKey(p as object) as string
    ' Order is fixed (not just "for each" over the AA, whose iteration order isn't
    ' guaranteed) so the same logical params always hash to the same string.
    fields = ["text", "binary", "ecl", "border", "pixel", "lightColor", "darkColor", "minVersion", "maxVersion", "mask", "boost"]
    parts = []
    for each f in fields
        v = p[f]
        if type(v) = "roInvalid" or v = invalid then
            parts.push(f + "=")
        else if f = "binary" then
            ' `binary` is an intarray -- .toStr() on an array is a generic type
            ' placeholder, not a content serialization, so every different byte
            ' payload would otherwise hash to the SAME key and silently return
            ' the wrong cached image. Join the actual byte values instead.
            parts.push(f + "=" + joinNums(v, ","))
        else
            parts.push(f + "=" + v.toStr())
        end if
    next
    raw = joinNums(parts, "&")
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(raw)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha1")
    return digest.Process(ba)
end function

' The thread-agnostic core. Given the same rendering params this always produces
' pixel-identical output, so it's safe to cache purely on the params.
'
' `p` fields: text OR binary (one required), ecl ("LOW"/"MEDIUM"/"QUARTILE"/"HIGH",
' default "LOW"), border (default 4), pixel (default 8), lightColor (default
' 0xFFFFFFFF), darkColor (default 0x000000FF), minVersion (default 1), maxVersion
' (default 40), mask (default -1), boost (default true).
'
' Returns { uri: string or invalid, cacheHit: boolean, error: string or invalid }.
' Never throws -- generation failures (e.g. "Data too long" for the given version
' range) come back as a populated `error` field instead, since a thrown exception
' crossing a Task's function boundary is awkward for a caller to handle cleanly.
function qrGenerateAndCache(p as object) as object
    result = { uri: invalid, cacheHit: false, error: invalid }

    key = qrCacheKey(p)
    dir = qrCacheDir()
    path = dir + "/" + key + ".png"

    fs = CreateObject("roFileSystem")
    if fs.Exists(path) then
        result.uri = path
        result.cacheHit = true
        return result
    end if

    try
        if not fs.Exists(dir) then
            ' Best-effort: another thread may create it between the check and here,
            ' which is fine -- CreateDirectory returning false in that case isn't
            ' an error, only a genuinely missing/unwritable volume is.
            fs.CreateDirectory(dir)
        end if

        ecl = CreateObject("roSGNode", "QREcc")
        ecl.level = iif(isNullOrEmpty(p.ecl), "LOW", uCase(p.ecl))

        qr = QrCode()
        minVersion = iif(p.minVersion = invalid, 1, p.minVersion)
        maxVersion = iif(p.maxVersion = invalid, 40, p.maxVersion)
        mask = iif(p.mask = invalid, -1, p.mask)
        boost = iif(p.boost = invalid, true, p.boost)

        if not isNullOrEmpty(p.text) then
            segs = qr.QrSegment.makeSegments(p.text)
            qr = qr.encodeSegments(segs, ecl, minVersion, maxVersion, mask, boost)
        else if p.binary <> invalid then
            seg = qr.QrSegment.makeBytes(p.binary)
            qr = qr.encodeSegments([seg], ecl, minVersion, maxVersion, mask, boost)
        else
            result.error = "Either text or binary is required"
            return result
        end if

        border = iif(p.border = invalid, 4, p.border)
        pixel = iif(p.pixel = invalid, 8, p.pixel)
        lightColor = iif(p.lightColor = invalid, &hFFFFFFFF, p.lightColor)
        darkColor = iif(p.darkColor = invalid, &h000000FF, p.darkColor)

        ok = qrRenderToFile(qr, path, border, pixel, lightColor, darkColor)
        if not ok then
            result.error = "Failed to render or write PNG"
            return result
        end if

        result.uri = path
        return result
    catch e
        result.error = "QR generation failed: " + e.message
        return result
    end try
end function

' Renders a constructed QrCode object to a PNG file at the given path. Pure
' roBitmap work -- no SceneGraph node involved -- so this is thread-agnostic too.
' Split out from qrGenerateAndCache() so a caller that already has a QrCode object
' (e.g. wants to inspect qr.size or qr.mask before deciding to keep it) can render
' it directly without going through the cache.
function qrRenderToFile(qr as object, path as string, border as integer, pixel as integer, lightColor as integer, darkColor as integer) as boolean
    size = qr.size
    imageSide = ((border * 2) + size) * pixel
    if imageSide <= 0 then return false

    bm = CreateObject("roBitmap", { width: imageSide, height: imageSide, AlphaEnable: true })
    if bm = invalid then return false

    bm.DrawRect(0, 0, imageSide, imageSide, lightColor)
    for y = 0 to size - 1
        for x = 0 to size - 1
            if qr.modules[y][x] = 1 then
                bm.DrawRect((border + x) * pixel, (border + y) * pixel, pixel, pixel, darkColor)
            end if
        next
    next
    bm.Finish()

    ba = bm.GetPng(0, 0, imageSide, imageSide)
    if ba = invalid then return false
    return ba.WriteFile(path)
end function

' Convenience wrapper for the async (Task-thread) path -- creates a QRCodeTask,
' wires the observer BEFORE triggering RUN (the ordering that actually avoids the
' documented race -- see https://developer.roku.com/dev/docs/task), and hands
' back the task node so the caller can track/cancel it if needed.
'
' `onDoneFunctionName` must be a function declared in the CALLING component's own
' .brs (this file gets included into that component's script scope, so
' observeField()'s callback-name lookup resolves against the caller, not against
' this file) -- it receives a roSGNodeEvent whose getData() is the same
' {uri, cacheHit, error} shape qrGenerateAndCache() returns directly.
'
' Called from the calling node's own code, e.g.:
'   m.qrTask = qrGenerateAsync({text: "hello"}, "onMyQrDone")
function qrGenerateAsync(p as object, onDoneFunctionName as string) as object
    task = CreateObject("roSGNode", "QRCodeTask")
    task.observeField("response", onDoneFunctionName)
    task.request = p
    task.control = "RUN"
    return task
end function
