// Visitor counter served by API Gateway -> Lambda -> DynamoDB
async function updateVisitorCount() {
   const el = document.getElementById('counter');
   try {
      const response = await fetch('https://v79afzfyc2.execute-api.us-east-1.amazonaws.com/prd/count');
      if (!response.ok) {
         throw new Error('Network response was not ok');
      }
      const data = await response.json();
      // Older Lambda versions wrapped the count in a JSON-encoded body string; handle both shapes
      const body = typeof data.body === 'string' ? JSON.parse(data.body) : data;
      el.textContent = Number(body.count).toLocaleString();
   } catch (error) {
      console.error('Error fetching visitor count:', error);
      el.textContent = 'n/a';
   }
}

// Light/dark toggle; remembers the choice per browser
function initThemeToggle() {
   const root = document.documentElement;
   try {
      const saved = localStorage.getItem('theme');
      if (saved) root.dataset.theme = saved;
   } catch (e) { /* storage unavailable */ }

   document.querySelector('.theme-toggle').addEventListener('click', () => {
      const current = root.dataset.theme
         || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const next = current === 'dark' ? 'light' : 'dark';
      root.dataset.theme = next;
      try { localStorage.setItem('theme', next); } catch (e) { /* storage unavailable */ }
   });
}

document.getElementById('year').textContent = new Date().getFullYear();
initThemeToggle();
updateVisitorCount();
