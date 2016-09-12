var xs = require('xstream').default;
var flattenConcurrently = require('xstream/extra/flattenConcurrently').default;
var concat = require('xstream/extra/concat').default;
var delay = require('xstream/extra/delay').default;

exports._addListener = function (klass) {
  return function (effL, s) {
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
};

exports._combine = function (klass1) {
  return function (klass2) {
    return function (klass3) {
      return function (p, s1, s2) {
        return xs.combine(
          s1,
          s2
        ).map(function (r) {
          return p(r[0])(r[1]);
        });
      };
    };
  };
};

exports._concat = function (klass) {
  return function (s1, s2) {
    return concat(s1, s2);
  };
};

exports._delay = function (klass) {
  return function (i, s) {
    return function () {
      return s.compose(delay(i));
    };
  };
};

exports._drop = function (klass) {
  return function (s, i) {
    return s.drop(i);
  };
};

exports._fold = function (klass) {
  return function (s, p, x) {
    return s.fold(function (b, a) {
      return p(b)(a);
    }, x);
  };
};

exports._empty = function (klass) {
  return xs.empty();
};

exports._endWhen = function (klass) {
  return function (s1, s2) {
    return s1.endWhen(s2);
  };
};

exports._filter = function (klass) {
  return function(s, p) {
    return s.filter(p);
  };
};

exports._flatMap = function (klass) {
  return function (s, p) {
    return s.map(function (a) {
      return p(a);
    }).compose(flattenConcurrently);
  };
};

exports._flatMapEff = function (klass) {
  return function (s, effP) {
    return function () {
      return s.map(function (a) {
        return effP(a)();
      }).compose(flattenConcurrently);
    };
  };
};

exports._imitate = function (s1, s2) {
  return function () {
    s1.imitate(s2);
  };
};

exports._last = function (klass) {
  return function (s) {
    return s.last();
  };
};

exports._map = function (klass) {
  return function (p, s, a, b, c) {
    return s.map(p);
  };
};

exports._mapTo = function (klass) {
  return function (s, v) {
    return s.mapTo(v);
  };
};

exports._merge = function (klass) {
  return function (s1, s2) {
    return xs.merge(s1, s2);
  };
};

exports._of = function (klass) {
  return xs.of;
};

exports._startWith = function (klass) {
  return function (s, x) {
    return s.startWith(x);
  };
};

exports._replaceError = function (klass) {
  return function (s, p) {
    return s.replaceError(p);
  };
};

exports._take = function (klass) {
  return function (s, i) {
    return s.take(i);
  };
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

exports.flatten = function (klass) {
  return function (s) {
    return s.flatten();
  };
};

exports.flattenEff = function (klass) {
  return function (s) {
    return function () {
      return s.map(function (effS) {
        return effS();
      }).flatten();
    };
  };
};

exports.fromArray = xs.fromArray;

exports.never = xs.never();

exports.periodic = function (t) {
  return function () {
    return xs.periodic(t);
  };
};

exports.remember = function (klass) {
  return function (s) {
    return s.remember()
  };
};

exports.throw = xs.throw;

exports.unsafeLog = function (a) {
  console.log(a);
}
