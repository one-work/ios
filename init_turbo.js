// name=minimal-turbo-stub.js
(function () {
  if (window.Turbo) return; // 不覆盖已有真实 Turbo

  function uid(prefix = "t") {
    return prefix + "-" + Math.random().toString(36).slice(2, 9);
  }

  const Turbo = {
    // adapter 注册点：native 注入端会调用 Turbo.registerAdapter(this)
    registerAdapter(adapter) {
      // 保存 adapter 引用，native 的 turbo.js 会期望 navigator.adapter == window.turboNative
      this.navigator.adapter = adapter;
      // 允许实现者立即决定是否通知 adapter（turbo.js 中 native 会自己调用 adapter.turboIsReady(true)）
    },

    // navigator API（提供最小必要方法/属性）
    navigator: {
      restorationIdentifier: uid("restoration"),
      adapter: null,
      // location 可直接使用 window.location（必须有 href）
      location: window.location,
      // 判断是否 same-page（可按需改进）
      locationWithActionIsSamePage(location, action) {
        try {
          const url = location instanceof URL ? location : new URL(location.toString(), window.location.href);
          return (url.pathname === window.location.pathname) && (url.search === window.location.search) && url.hash !== "";
        } catch (e) {
          return false;
        }
      },

      // startVisit：创建一个简单 visit 对象，并尝试通知 adapter 的生命周期回调以模拟完整流程
      startVisit(location, restorationIdentifier, options) {
        const id = uid("visit");
        const visitLocation = (typeof location === "string" || location instanceof String) ? location : (location && location.toString ? location.toString() : String(location));
        const visit = {
          identifier: id,
          location: { toString: () => visitLocation },
          restorationIdentifier: restorationIdentifier || Turbo.navigator.restorationIdentifier,
          isPageRefresh: false,
          hasCachedSnapshot() { return false; },

          // 以下方法会被 native 通过 adapter.currentVisit 调用；实现为空/安全
          issueRequest() { /* noop or trigger ajax if you want */ },
          changeHistory() { /* noop */ },
          loadCachedSnapshot() { /* noop */ },
          loadResponse() { /* noop */ },
          cancel() { /* noop */ }
        };

        // 将 currentVisit 存回 adapter（native turbo.js 依赖 adapter.currentVisit）
        const adapter = Turbo.navigator.adapter;
        if (adapter) {
          try {
            adapter.currentVisit = visit;
            if (typeof adapter.visitStarted === "function") adapter.visitStarted(visit);
            if (typeof adapter.visitRequestStarted === "function") adapter.visitRequestStarted(visit);

            // 模拟一个成功的请求/渲染流程（可以改为异步）
            if (typeof adapter.visitRequestCompleted === "function") adapter.visitRequestCompleted(visit);
            if (typeof adapter.visitRequestFinished === "function") adapter.visitRequestFinished(visit);
            // 在下一次重绘后告知渲染完成
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                if (typeof adapter.visitRendered === "function") adapter.visitRendered(visit);
                if (typeof adapter.visitCompleted === "function") adapter.visitCompleted(visit);
              });
            });
          } catch (e) {
            console.warn("Turbo stub: adapter callback error", e);
          }
        }

        return visit;
      },

      view: {
        scrollToAnchorFromLocation(location) {
          try {
            const url = (location instanceof URL) ? location : new URL(location.toString(), window.location.href);
            const hash = url.hash;
            if (hash) {
              const el = document.getElementById(hash.slice(1)) || document.querySelector(hash);
              if (el) el.scrollIntoView();
            }
          } catch (e) {
            // ignore
          }
        }
      }
    },

    // session API：清缓存与快照
    session: {
      clearCache() { /* noop */ },
      view: {
        cacheSnapshot() { /* noop */ }
      }
    }
  };

  window.Turbo = Turbo;

  // 如果需要让 turbo.js 的 setupOnLoad 跳过超时，触发 turbo:load（在你初始化完 Turbo 后触发）
  // turbo.js 会监听这个事件以完成注册流程
  setTimeout(() => {
    document.dispatchEvent(new Event("turbo:load"));
  }, 0);
})();
