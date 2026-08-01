(() => {
  // 防止重复插入（Hotwire 跳转时可能会重复触发）
  if (document.getElementById('init')) return

  const script = document.createElement('script')
  script.id = 'init'
  script.src = 'https://assets.linlishenghuo.com/assets/printer-00000031.digested.js'
  document.head.appendChild(script)

  console.debug('注入 js 成功！')
})()
