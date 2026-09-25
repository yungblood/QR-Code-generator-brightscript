sub init()
    m.top.setFocus(true)

    ' Demonstrates the Task-thread path: qrGenerateAsync() runs generation on
    ' QRCodeTask's own thread, not this scene's render thread, so it never
    ' blocks/hitches the UI -- unlike the plain <qrCode> examples above, which
    ' generate synchronously the moment their `text` field is set.
    m.taskStatusLabel = m.top.findNode("taskStatusLabel")
    m.taskQrPoster = m.top.findNode("taskQrPoster")
    m.qrTask = qrGenerateAsync({ text: "https://www.paramountplus.com/", ecl: "HIGH" }, "onTaskQrDone")
end sub

sub onTaskQrDone(event as object)
    result = event.getData()
    if result.error <> invalid then
        m.taskStatusLabel.text = "Task thread error: " + result.error
        return
    end if
    m.taskQrPoster.uri = result.uri
    m.taskStatusLabel.text = "Generated via Task thread (cache hit: " + result.cacheHit.toStr() + ")"
end sub
