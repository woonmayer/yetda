ObjC.import('Vision'); ObjC.import('Foundation');
function run(argv) {
  var url = $.NSURL.fileURLWithPath(argv[0]);
  var out = [];
  [['standard', false], ['CPU only', true]].forEach(function (a) {
    var req = $.VNRecognizeTextRequest.alloc.init;
    req.recognitionLevel = 0; req.usesLanguageCorrection = false;
    if (a[1]) req.usesCPUOnly = true;
    var h = $.VNImageRequestHandler.alloc.initWithURLOptions(url, $());
    var err = Ref();
    var t = Date.now();
    var ok = h.performRequestsError($([req]), err);
    var n = ok ? req.results.count : -1;
    var first = (ok && n > 0) ? ObjC.unwrap(req.results.objectAtIndex(0).topCandidates(1).objectAtIndex(0).string) : '';
    out.push(a[0] + ': ' + (ok ? 'OK ' + n + ' lines "' + first + '"' : 'FAIL ' + ObjC.unwrap(err[0].localizedDescription)) + ' (' + (Date.now() - t) + 'ms)');
  });
  return out.join('\n');
}
