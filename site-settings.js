(()=>{
 const cfg=window.GRAPHYSICS_CONFIG||{};
 const ready=!!(window.supabase&&cfg.SUPABASE_URL&&!cfg.SUPABASE_URL.includes('YOUR_')&&cfg.SUPABASE_ANON_KEY&&!cfg.SUPABASE_ANON_KEY.includes('YOUR_'));
 if(!ready)return;
 const db=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY);
 const apply=async()=>{
  const {data,error}=await db.from('site_settings').select('settings').eq('id','homepage').maybeSingle();
  if(error||!data?.settings)return;
  const x=data.settings, title=document.getElementById('siteHeroTitle'), sub=document.getElementById('siteHeroSubtitle'), eye=document.getElementById('siteHeroEyebrow'), btn=document.getElementById('siteHeroButton');
  if(title&&x.heroTitle)title.innerHTML=String(x.heroTitle).split('\n').map((line,i,a)=>i===a.length-1?'<span class=\"gradient-text\">'+safe(line)+'</span>':safe(line)).join('<br>');
  if(sub&&x.heroSubtitle)sub.textContent=x.heroSubtitle;
  if(eye&&x.eyebrow)eye.innerHTML='<span class="pulse"></span> '+safe(x.eyebrow);
  if(btn&&x.buttonText)btn.innerHTML=safe(x.buttonText)+' <span>↗</span>';
  const root=document.documentElement;
  if(x.primary)root.style.setProperty('--purple',x.primary);
  if(x.accent)root.style.setProperty('--pink',x.accent);
  if(x.background)root.style.setProperty('--paper',x.background);
  const hero=document.querySelector('.hero');
  if(hero&&x.heroImage)hero.style.backgroundImage=`linear-gradient(90deg,rgba(23,19,41,.92),rgba(23,19,41,.65)),url("${String(x.heroImage).replace(/["\\]/g,'')}")`;
  const hidden=new Set(x.hiddenSections||[]);
  (x.sectionOrder||[]).forEach((id,i)=>{const el=document.querySelector(`[data-site-section="${id}"]`);if(el){el.style.order=String(i);el.style.display=hidden.has(id)?'none':'';}});
  document.querySelector('main')?.style.setProperty('display','flex');
  document.querySelector('main')?.style.setProperty('flex-direction','column');
 };
 const safe=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 document.addEventListener('DOMContentLoaded',apply);
})();