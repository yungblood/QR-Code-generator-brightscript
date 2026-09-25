' Defaults functionName so callers only need to set `request` then control="RUN" --
' this Task only ever does one job, so there's no reason to make every caller
' remember to name it. A caller can still override functionName before RUN if
' this component is ever extended with more than one task function.
sub init()
    m.top.functionName = "generate"
end sub

' Runs on this Task's own thread (see the base Task node mechanism this relies
' on: https://developer.roku.com/dev/docs/task). Reads `request` and writes
' `response` -- Task functions take no parameters and return no value, input and
' output only ever move through interface fields.
sub generate()
    m.top.response = qrGenerateAndCache(m.top.request)
end sub
