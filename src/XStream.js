var xs = require('xstream').default;
var flattenConcurrently = require('xstream/extra/flattenConcurrently').default;
var concat = require('xstream/extra/concat').default;
var delay = require('xstream/extra/delay').default;

exports._addListener = function (effL, s) {
  return function () {
    return s.addListener({
      next: function (a) {
        return effL.next(a)();
      },
      error: function (e) {
        return effL.error(e)();
      },
      complete: function () {
        return effL.complete()();
      }
    });
  };
};

exports._combine = function (p, s1, s2) {
  return xs.combine(
    s1,
    s2
  ).map(function (r) {
    return p(r[0])(r[1]);
  });
};

exports._concat = function (s1, s2) {
  return concat(s1, s2);
};

exports._delay = function (i, s) {
  return function () {
    return s.compose(delay(i));
  };
};

exports._drop = function (s, i) {
  return s.drop(i);
};

exports._fold = function (s, p, x) {
  return s.fold(function (b, a) {
    return p(b)(a);
  }, x);
};

exports._empty = xs.empty();

exports._endWhen = function (s1, s2) {
  return s1.endWhen(s2);
};

exports._filter = function(s, p) {
  return s.filter(p);
};

exports._flatMap = function (s, p) {
  return s.map(p).compose(flattenConcurrently);
};

exports._flatMapEff = function (s, effP) {
  return function () {
    return s.map(function (a) {
      var result = effP(a)();
      return result;
    }).compose(flattenConcurrently);
  };
};

exports._flatMapLatest = function (s, p) {
  return s.map(p).flatten();
};

exports._flatMapLatestEff = function (s, effP) {
  return function () {
    return s.map(function (a) {
      var result = effP(a)();
      return result;
    }).flatten();
  };
};

exports._imitate = function (s1, s2) {
  return function () {
    s1.imitate(s2);
  };
};

exports._last = function (s) {
  return s.last();
};

exports._map = function (p, s) {
  return s.map(p);
};

exports._mapTo = function (s, v) {
  return s.mapTo(v);
};

exports._merge = function (s1, s2) {
  return xs.merge(s1, s2);
};

exports._of = xs.of;

exports._startWith = function (s, x) {
  return s.startWith(x);
};

exports._replaceError = function (s, p) {
  return s.replaceError(p);
}

exports._take = function (s, i) {
  return s.take(i);
};

var adaptListenerToEff = function (l) {
  return {
    next: function (x) {
      return function () {
        l.next(x);
      }
    },
    error: function (e) {
      return function () {
        l.error(e);
      }
    },
    complete: function () {
      return function () {
        l.complete();
      }
    }
  };
};

var adaptEffProducer = function (p) {
  return {
    start: function (x) {
      return p.start(adaptListenerToEff(x))();
    },
    stop: function () {
      return p.stop()();
    }
  };
};

exports.create = function (p) {
  return function () {
    return xs.create(adaptEffProducer(p));
  };
};

exports["create'"] = function () {
  return function () {
    return xs.create();
  };
};

exports.createWithMemory = function (p) {
  return function () {
    return xs.createWithMemory(adaptEffProducer(p));
  };
};

exports.flatten = function (s) {
  return s.flatten();
};

exports.flattenEff = function (s) {
  return function () {
    return s.map(function (effS) {
      return effS();
    }).flatten();
  };
};

exports.fromArray = xs.fromArray;

exports.never = xs.never();

exports.periodic = function (t) {
  return function () {
    return xs.periodic(t);
  };
};

exports.remember = function (s) {
  return s.remember()
};

exports.throw = xs.throw;

exports.unsafeLog = function (a) {
  return function () {
    console.log(a);
  }
}
