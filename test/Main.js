exports.callback = function (effCb) {
  return function () {
    effCb(1)();
  };
};
