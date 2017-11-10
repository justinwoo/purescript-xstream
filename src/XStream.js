var xs = require('xstream').default;
var flattenConcurrently = require('xstream/extra/flattenConcurrently').default;
var concat = require('xstream/extra/concat').default;
var delay = require('xstream/extra/delay').default;

exports._addListener = function (spec, s) {
  return s.addListener(spec);
};

exports._subscribe = function (effL, s) {
  return s.subscribe(effL);
};

exports._cancelSubscription = function (sub) {
  return sub.unsubscribe();
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
  return s.compose(delay(i));
};

exports._drop = function (i, s) {
  return s.drop(i);
};

exports._fold = function (p, x, s) {
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

exports._flatMapEff = function (effP, s) {
  return s.map(effP).compose(flattenConcurrently);
};

exports._flatMapLatest = function (s, p) {
  return s.map(p).flatten();
};

exports._flatMapLatestEff = function (effP, s) {
  return s.map(effP).flatten();
};

exports._imitate = function (s1, s2) {
  s1.imitate(s2);
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
};

exports._take = function (i, s) {
  return s.take(i);
};

exports._create = function (p) {
  return xs.create(p);
};

exports.__create = function () {
  return xs.create();
};

exports._createWithMemory = function (p) {
  return xs.createWithMemory(p);
};

exports.flatten = function (s) {
  return s.flatten();
};

exports._flattenEff = function (s) {
  return s.map(function (effS) {
    return effS();
  }).flatten();
};

exports.fromArray = xs.fromArray;

exports.never = xs.never();

exports._periodic = function (t) {
  return xs.periodic(t);
};

exports.remember = function (s) {
  return s.remember();
};

exports.throw = xs.throw;

exports.unsafeLog = function (a) {
  console.log(a);
};

exports._shamefullySendNext = function (x, s) {
  s.shamefullySendNext(x);
};

exports._shamefullySendError = function (e, s) {
  s.shamefullySendError(e);
};

exports._shamefullySendComplete = function (_, s) {
  s.shamefullySendComplete();
};

// have to do this manually or else the context will be wrong/undefined
exports.adaptListener = function (l) {
  return {
    next: function (x) {
      l.next(x)();
    },
    error: function (x) {
      l.error(x)();
    },
    complete: function () {
      l.complete()();
    }
  };
};

// have to do this manually or else the context will be wrong/undefined
exports.reverseListener = function (effL) {
  return {
    next: function (x) {
      return function () {
        effL.next(x);
      };
    },
    error: function (x) {
      return function () {
        effL.error(x);
      };
    },
    complete: function () {
      return function () {
        effL.complete();
      };
    }
  };
};
