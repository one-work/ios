(() => {
  // 防止重复插入（Hotwire 跳转时可能会重复触发）
  if (document.getElementById('my-injected-script')) return;

  const script = document.createElement('script');
  script.id = 'my-injected-script';
  script.src = 'https://your-cdn.com/my-script.js';
  script.type = 'text/javascript';
  
  console.debug('ddd', document)
  document.head.appendChild(script);

  console.debug('注入 js  成功！')
})()
