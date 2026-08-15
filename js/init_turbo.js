(() => {
 // 防止重复插入（Hotwire 跳转时可能会重复触发）
 if (document.getElementById('init_turbo')) return

 const script = document.createElement('script')
 script.id = 'init_turbo'
 script.src = 'https://assets.linlishenghuo.com/assets/turbo-00000001.digested.js'
 document.head.appendChild(script)

 console.debug('注入 Turbo Mock js 成功！')
})()
