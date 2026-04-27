import { useState } from "react";
import { RadarChart, Radar, PolarGrid, PolarAngleAxis, ResponsiveContainer } from "recharts";

// ─── Actual centroids from results_italy_5dim.rds ───────────────────────────
// Mapped by inspecting cluster means:
// K6.1: low income (8.36), moderate internet, → Fragili Economici
// K6.2: internet 0.856 (highest), eurod 1.53 (lowest), mobility 0.74 → Connessi Attivi
// K6.3: internet 0.695, decent health, good casp → Moderati Digitali
// K6.4: sn_size 3.612 (highest!), internet 0.189 (very low) → Sociali Tradizionali
// K6.5: sn_size 1.389 (LOWEST!), low internet → Isolati Silenziosi (Moderate Isolated)
// K6.6: eurod 5.89, mobility 5.20, casp 27.80, lonely 6.16 (worst all dims) → Fragili Multiproblematici

const CENTROIDS = {
  K6_1: { internet:0.303, sn_size:2.446, soc_int:2.405, fluency:13.215, casp:32.86, lonely:4.84, eurod:3.35, mobility:2.62, income:8.36, hope:0.80 },
  K6_2: { internet:0.856, sn_size:2.638, soc_int:3.133, fluency:19.110, casp:38.54, lonely:3.67, eurod:1.53, mobility:0.74, income:9.93, hope:0.92 },
  K6_3: { internet:0.695, sn_size:2.866, soc_int:3.117, fluency:18.916, casp:37.20, lonely:3.97, eurod:2.51, mobility:1.33, income:9.72, hope:0.86 },
  K6_4: { internet:0.189, sn_size:3.612, soc_int:3.616, fluency:14.967, casp:34.96, lonely:4.11, eurod:2.33, mobility:1.99, income:8.79, hope:0.87 },
  K6_5: { internet:0.247, sn_size:1.389, soc_int:1.785, fluency:13.669, casp:34.22, lonely:4.56, eurod:2.49, mobility:1.23, income:8.29, hope:0.81 },
  K6_6: { internet:0.067, sn_size:2.297, soc_int:2.189, fluency:10.122, casp:27.80, lonely:6.16, eurod:5.89, mobility:5.20, income:9.10, hope:0.44 },
};

const PROFILES = {
  K6_1: {
    label:"Fragili Economici", icon:"💸", color:"#E07B39", n:195, pct:"8.6%",
    tag:"Vulnerabilità economica",
    desc:"Risorse economiche sotto la media, accesso digitale limitato ma presente, alcune difficoltà di salute. Non i più isolati socialmente, ma vulnerabili per la dimensione economica e a rischio di esclusione dai servizi digitali a pagamento.",
    recs:[
      "Verifica accesso a bonus INPS, pensione minima, agevolazioni tariffarie",
      "Screening per difficoltà materiali: farmaci, alimentazione, utenze",
      "Supporto guidato per SPID e Fascicolo Sanitario Elettronico",
      "Connessione con sportelli sociali comunali e patronati",
    ],
    se:"Nessun equivalente diretto in Svezia — il welfare universalistico e i trasferimenti pubblici prevengono questa configurazione nel campione svedese."
  },
  K6_2: {
    label:"Connessi Attivi", icon:"🌐", color:"#3B82F6", n:437, pct:"19.3%",
    tag:"Profilo più favorevole",
    desc:"Alta adozione digitale, ottima salute fisica, bassi livelli di depressione e solitudine. Cognitivamente attivi, orientati al futuro con buone aspettative di sopravvivenza. Basso rischio a breve termine.",
    recs:[
      "Mantenimento: attività culturali, volontariato, formazione continua",
      "Coinvolgerli come facilitatori digitali peer-to-peer per altri anziani",
      "Prevenzione primaria con screening periodico leggero",
      "Monitoraggio longitudinale per individuare precocemente eventuali transizioni",
    ],
    se:"Corrisponde al 'Connected Wealthy' svedese (K6.1 SE, internet 94%) — ma la controparte svedese ha CASP +5 punti e fluency verbale +8 punti."
  },
  K6_3: {
    label:"Moderati Digitali", icon:"💻", color:"#8B5CF6", n:239, pct:"10.5%",
    tag:"Profilo intermedio con buon digitale",
    desc:"Buona connessione digitale e condizioni di salute moderate. Simile ai Connessi Attivi ma con più fragilità e benessere leggermente inferiore. Rischio di scivolamento verso isolamento se le condizioni peggiorano.",
    recs:[
      "Stimolazione cognitiva attraverso uso attivo e diversificato della tecnologia",
      "Supporto per partecipazione ad attività digitali di gruppo (corsi, videochiamata)",
      "Monitoraggio salute con strumenti digitali: FSE, telemedicina, app di salute",
      "Rafforzamento delle reti sociali informali — il sn_size è nella media ma fragile",
    ],
    se:"Comparabile al profilo 'Moderate' svedese (K6.2 SE, n=428) — la Svezia mostra CASP ~40.9 vs 37.2 italiano per profili simili."
  },
  K6_4: {
    label:"Sociali Tradizionali", icon:"👥", color:"#10B981", n:456, pct:"20.1%",
    tag:"Rete sociale forte, digitale assente",
    desc:"La rete sociale più ampia del campione (sn_size 3.6) con ottima integrazione comunitaria, ma quasi nessun accesso digitale (solo 19%). Protetti dall'isolamento dalle reti tradizionali, ma acutamente vulnerabili all'esclusione dai servizi che si stanno digitalizzando con il PNRR.",
    recs:[
      "PRIORITÀ: alfabetizzazione digitale adattata — SPID, CUP online, fascicolo sanitario",
      "Intercettazione tramite canali tradizionali: parrocchie, centri anziani, medico di base",
      "Mediatori digitali familiari: coinvolgere figli/nipoti nell'onboarding tecnologico",
      "Vigilanza durante la digitalizzazione PNRR: non devono perdere accesso alla sanità",
    ],
    se:"Simile al 'Moderate' svedese ma con gap digitale molto più ampio — in Svezia il 60% degli anziani usa internet vs 19% in questo profilo italiano."
  },
  K6_5: {
    label:"Isolati Silenziosi", icon:"🔇", color:"#F59E0B", n:522, pct:"23.0%",
    tag:"Profilo più numeroso · fenomeno sistemico",
    desc:"Il profilo più grande del campione (~3.8M italiani): condizioni oggettive di salute ed economiche nella norma, ma rete sociale minima (sn_size 1.39, il più basso). Invisibili ai sistemi di monitoraggio perché 'non hanno patologie'. Rischio di deterioramento silenzioso e progressivo.",
    recs:[
      "URGENTE: intercettazione attiva — non si presenteranno spontaneamente ai servizi",
      "Programmi di socializzazione strutturata: centri diurni, gruppi attività fisica",
      "Volontariato di prossimità: visite regolari programmate da associazioni",
      "Screening per depressione subclinica e deterioramento cognitivo precoce",
      "Il medico di base come principale — spesso unico — punto di aggancio",
    ],
    se:"⚠️ ASSENTE in Svezia: nessun cluster svedese ha sn_size media sotto 2.85. L'isolamento estremo di quasi il 30% degli anziani italiani è un fenomeno sistemico, non individuale."
  },
  K6_6: {
    label:"Fragili Multiproblematici", icon:"🆘", color:"#EF4444", n:418, pct:"18.4%",
    tag:"Priorità assoluta di intervento",
    desc:"Fragilità fisica severa (mobility 5.2), alta depressione (EURO-D 5.9), estrema solitudine (lonely 6.2), quasi nessun accesso digitale (7%), declino cognitivo (fluency 10.1). Il profilo con i bisogni più urgenti e la qualità di vita percepita più bassa (CASP 27.8).",
    recs:[
      "PRIORITÀ MASSIMA: valutazione multidimensionale geriatrica (VMD) immediata",
      "Attivazione o verifica dell'Assistenza Domiciliare Integrata (ADI)",
      "Trattamento depressione: EURO-D alto è predittore indipendente di mortalità",
      "Valutazione della rete di cura informale: esiste un caregiver? È sostenibile?",
      "NON affidarsi a canali digitali — solo contatto fisico diretto e telefono",
    ],
    se:"Corrisponde al 'Fragile' svedese (K6.3 SE) — ma la controparte svedese ha CASP 33.25 vs 27.80 italiano, EURO-D 4.63 vs 5.89: stessa struttura, conseguenze peggiori in Italia."
  },
};

// ─── Normalization ───────────────────────────────────────────────────────────
const RANGES = {
  internet:{min:0,max:1}, sn_size:{min:1,max:7}, soc_int:{min:1,max:4},
  fluency:{min:0,max:35}, casp:{min:12,max:48}, lonely:{min:3,max:9},
  eurod:{min:0,max:12}, mobility:{min:0,max:6}, income:{min:7,max:12}, hope:{min:0,max:1}
};

function norm(val, key) {
  const {min,max} = RANGES[key];
  return (val - min) / (max - min);
}

function euclidean(a, b) {
  return Math.sqrt(Object.keys(RANGES).reduce((s, k) => s + (norm(a[k],k) - norm(b[k],k))**2, 0));
}

function classify(ans) {
  return Object.entries(CENTROIDS)
    .map(([k,c]) => ({k, d: euclidean(ans, c)}))
    .sort((a,b) => a.d - b.d)[0].k;
}

function dimScores(ans) {
  const health    = 100 - ((norm(ans.eurod,'eurod') + norm(ans.mobility,'mobility')) / 2 * 100);
  const digital   = (norm(ans.internet,'internet') + norm(ans.sn_size,'sn_size') + norm(ans.soc_int,'soc_int')) / 3 * 100;
  const cognitive = norm(ans.fluency,'fluency') * 100;
  const subjective= ((norm(ans.casp,'casp') + (1 - norm(ans.lonely,'lonely')) + ans.hope) / 3 * 100);
  const economic  = norm(ans.income,'income') * 100;
  return {health,digital,cognitive,subjective,economic};
}

// ─── Component ───────────────────────────────────────────────────────────────
const INIT = { internet:null, sn_size:4, soc_int:2, fluency:14, eurod:3, mobility:2, casp:35, lonely:5, hope:null, income:null };

const S = {
  page: { background:"#0F172A", minHeight:"100vh", fontFamily:"'DM Sans',system-ui,sans-serif", color:"#F1F5F9", fontSize:"15px" },
  header: { borderBottom:"1px solid #1E293B", padding:"0.9rem 1.5rem", display:"flex", alignItems:"center", justifyContent:"space-between" },
  card: { background:"#1E293B", borderRadius:14, padding:"1.25rem" },
  btn: (active, color="#3B82F6") => ({ flex:1, padding:"0.55rem 0.75rem", borderRadius:8, cursor:"pointer", fontWeight: active?600:400,
    border:`2px solid ${active?color:"#334155"}`, background: active ? color+"22" : "transparent", color:"white", transition:"all 0.15s" }),
  primary: (color="#3B82F6") => ({ width:"100%", background:color, color:"white", border:"none", padding:"0.85rem", borderRadius:10,
    fontSize:"1rem", fontWeight:600, cursor:"pointer" }),
  secondary: { width:"100%", background:"transparent", color:"#64748B", border:"1px solid #334155", padding:"0.75rem", borderRadius:10, cursor:"pointer" },
  label: { fontWeight:600, marginBottom:5 },
  hint: { color:"#64748B", fontSize:"0.8rem", marginBottom:8 },
  sliderRow: { display:"flex", justifyContent:"space-between", fontSize:"0.75rem", color:"#64748B", marginTop:4 },
};

export default function SilverItaly() {
  const [screen, setScreen] = useState(0);
  const [ans, setAns] = useState({...INIT});
  const [profileKey, setProfileKey] = useState(null);
  const set = (k,v) => setAns(p => ({...p,[k]:v}));

  const go = (s) => setScreen(s);
  const reset = () => { setAns({...INIT}); setProfileKey(null); setScreen(0); };
  const finish = () => { const k = classify(ans); setProfileKey(k); go(4); };

  const profile = profileKey ? PROFILES[profileKey] : null;
  const scores  = profileKey ? dimScores(ans) : null;
  const cScores = profileKey ? dimScores(CENTROIDS[profileKey]) : null;
  const radar   = scores ? [
    {dim:"Salute",     me:Math.round(scores.health),      cp:Math.round(cScores.health)},
    {dim:"Digitale",   me:Math.round(scores.digital),     cp:Math.round(cScores.digital)},
    {dim:"Cognitivo",  me:Math.round(scores.cognitive),   cp:Math.round(cScores.cognitive)},
    {dim:"Soggettivo", me:Math.round(scores.subjective),  cp:Math.round(cScores.subjective)},
    {dim:"Economico",  me:Math.round(scores.economic),    cp:Math.round(cScores.economic)},
  ] : [];

  const pct = screen===0?0 : screen===4?100 : Math.round((screen/3)*100);

  return (
    <div style={S.page}>

      {/* ── HEADER ── */}
      <div style={S.header}>
        <div>
          <span style={{fontWeight:700, color:"#60A5FA", fontSize:"1rem"}}>Silver Italy</span>
          <span style={{color:"#334155", marginLeft:8, fontSize:"0.75rem"}}>Profiler Anziani · SHARE Wave 9</span>
        </div>
        {screen>0 && screen<4 && <div style={{fontSize:"0.8rem", color:"#475569"}}>Step {screen} / 3</div>}
      </div>

      {/* ── PROGRESS BAR ── */}
      <div style={{height:3, background:"#1E293B"}}>
        <div style={{height:"100%", background: profile?.color||"#3B82F6", width:`${pct}%`, transition:"width 0.4s"}} />
      </div>

      <div style={{maxWidth:620, margin:"0 auto", padding:"1.75rem 1rem 3rem"}}>

        {/* ═══ SCREEN 0: INTRO ═══ */}
        {screen===0 && (
          <div style={{textAlign:"center"}}>
            <div style={{fontSize:"2.8rem", marginBottom:"0.75rem"}}>🧓</div>
            <h1 style={{fontSize:"1.75rem", fontWeight:700, margin:"0 0 0.5rem"}}>Silver Italy Profiler</h1>
            <p style={{color:"#94A3B8", lineHeight:1.65, maxWidth:460, margin:"0 auto 0.5rem"}}>
              Strumento di profilazione multidimensionale per anziani (65+), basato sul clustering reale su SHARE Wave 9.
            </p>
            <p style={{color:"#475569", fontSize:"0.82rem", marginBottom:"2rem"}}>
              10 domande → 6 profili italiani → raccomandazioni evidence-based + confronto Italia–Svezia
            </p>

            {/* Profile grid preview */}
            <div style={{display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:8, marginBottom:"2rem"}}>
              {Object.values(PROFILES).map(p=>(
                <div key={p.label} style={{background:"#1E293B", borderRadius:10, padding:"0.7rem 0.6rem", borderLeft:`3px solid ${p.color}`, textAlign:"left"}}>
                  <div style={{fontSize:"1.3rem"}}>{p.icon}</div>
                  <div style={{fontSize:"0.72rem", fontWeight:600, color:"#CBD5E1", marginTop:3, lineHeight:1.3}}>{p.label}</div>
                  <div style={{fontSize:"0.68rem", color:"#475569"}}>{p.pct} del campione</div>
                </div>
              ))}
            </div>

            <button onClick={()=>go(1)} style={{...S.primary(), maxWidth:260}}>Inizia profilazione →</button>
            <p style={{color:"#334155", fontSize:"0.72rem", marginTop:"1rem"}}>
              Basato su n=2.267 anziani italiani · SHARE Wave 9 release 9.0.0
            </p>
          </div>
        )}

        {/* ═══ SCREEN 1: DIGITALE & SOCIALE ═══ */}
        {screen===1 && (
          <div>
            <div style={{display:"inline-block", background:"#1E293B", borderRadius:6, padding:"2px 8px", fontSize:"0.72rem", color:"#60A5FA", marginBottom:8}}>DIMENSIONE 1–3 / 5</div>
            <h2 style={{fontSize:"1.35rem", fontWeight:700, margin:"0 0 4px"}}>Digitale & Sociale</h2>
            <p style={{color:"#64748B", marginBottom:"1.5rem", fontSize:"0.88rem"}}>Connessione digitale e struttura della rete sociale</p>

            {/* Internet */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Usa internet regolarmente?</div>
              <div style={{display:"flex", gap:8}}>
                {[["Sì ✓",1],["No ✗",0]].map(([lb,v])=>(
                  <button key={v} onClick={()=>set("internet",v)} style={S.btn(ans.internet===v, "#3B82F6")}>{lb}</button>
                ))}
              </div>
            </div>

            {/* Social network size */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Rete sociale — persone di fiducia <span style={{color:"#60A5FA", fontWeight:700}}>{ans.sn_size}</span></div>
              <div style={S.hint}>1 = nessuna persona di riferimento · 7 = rete ampia (5+ persone)</div>
              <input type="range" min={1} max={7} step={1} value={ans.sn_size} onChange={e=>set("sn_size",+e.target.value)}
                style={{width:"100%", accentColor:"#3B82F6", margin:"2px 0"}} />
              <div style={S.sliderRow}><span>1</span><span>7</span></div>
            </div>

            {/* Social integration */}
            <div style={{...S.card, marginBottom:"1.5rem"}}>
              <div style={S.label}>Integrazione sociale</div>
              <div style={S.hint}>1 = isolato, 4 = molto integrato (partecipa ad attività, gruppi, associazioni)</div>
              <div style={{display:"flex", gap:6}}>
                {[1,2,3,4].map(v=>(
                  <button key={v} onClick={()=>set("soc_int",v)} style={{...S.btn(ans.soc_int===v), flex:1}}>
                    <div style={{fontWeight:700}}>{v}</div>
                    <div style={{fontSize:"0.65rem", color:"#64748B"}}>{["isolato","scarso","medio","ottimo"][v-1]}</div>
                  </button>
                ))}
              </div>
            </div>

            <button onClick={()=>go(2)} style={{...S.primary(), opacity:ans.internet===null?0.45:1}} disabled={ans.internet===null}>
              Continua →
            </button>
          </div>
        )}

        {/* ═══ SCREEN 2: SALUTE & COGNITIVO ═══ */}
        {screen===2 && (
          <div>
            <div style={{display:"inline-block", background:"#1E293B", borderRadius:6, padding:"2px 8px", fontSize:"0.72rem", color:"#F59E0B", marginBottom:8}}>DIMENSIONE 4 / 5</div>
            <h2 style={{fontSize:"1.35rem", fontWeight:700, margin:"0 0 4px"}}>Salute & Cognitivo</h2>
            <p style={{color:"#64748B", marginBottom:"1.5rem", fontSize:"0.88rem"}}>Valutazione funzionale, depressiva e cognitiva</p>

            {/* EURO-D */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Depressione EURO-D <span style={{color:"#EF4444", fontWeight:700}}>{ans.eurod}/12</span></div>
              <div style={S.hint}>0 = nessun sintomo · 12 = sintomatologia severa (soglia clinica: 4+)</div>
              <input type="range" min={0} max={12} step={1} value={ans.eurod} onChange={e=>set("eurod",+e.target.value)}
                style={{width:"100%", accentColor:"#EF4444"}} />
              <div style={S.sliderRow}><span>0 — nessuno</span><span>12 — severo</span></div>
            </div>

            {/* Mobility */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Limitazioni mobilità <span style={{color:"#F59E0B", fontWeight:700}}>{ans.mobility}/6</span></div>
              <div style={S.hint}>0 = nessuna · 6 = gravi (scale, cammino 100m, piegarsi...)</div>
              <input type="range" min={0} max={6} step={1} value={ans.mobility} onChange={e=>set("mobility",+e.target.value)}
                style={{width:"100%", accentColor:"#F59E0B"}} />
              <div style={S.sliderRow}><span>0 — nessuna</span><span>6 — gravi</span></div>
            </div>

            {/* Fluency */}
            <div style={{...S.card, marginBottom:"1.5rem"}}>
              <div style={S.label}>Verbal fluency — animali in 60 secondi</div>
              <div style={S.hint}>Test neuropsicologico standard. Media campione italiano: 14.8 · Media svedese: 22.9</div>
              <input type="number" min={0} max={60} value={ans.fluency} onChange={e=>set("fluency",Math.max(0,+e.target.value))}
                style={{width:"100%", background:"#0F172A", border:"2px solid #334155", borderRadius:8, padding:"0.6rem 0.8rem",
                  color:"white", fontSize:"1.2rem", fontWeight:600, outline:"none", boxSizing:"border-box"}} />
            </div>

            <div style={{display:"flex", gap:8}}>
              <button onClick={()=>go(1)} style={{...S.secondary, flex:"0 0 90px"}}>← Indietro</button>
              <button onClick={()=>go(3)} style={{...S.primary(), flex:1}}>Continua →</button>
            </div>
          </div>
        )}

        {/* ═══ SCREEN 3: SOGGETTIVO & ECONOMICO ═══ */}
        {screen===3 && (
          <div>
            <div style={{display:"inline-block", background:"#1E293B", borderRadius:6, padding:"2px 8px", fontSize:"0.72rem", color:"#10B981", marginBottom:8}}>DIMENSIONE 5 / 5</div>
            <h2 style={{fontSize:"1.35rem", fontWeight:700, margin:"0 0 4px"}}>Soggettivo & Economico</h2>
            <p style={{color:"#64748B", marginBottom:"1.5rem", fontSize:"0.88rem"}}>Percezione di sé e risorse economiche disponibili</p>

            {/* CASP */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Qualità di vita CASP-12 <span style={{color:"#10B981", fontWeight:700}}>{ans.casp}/48</span></div>
              <div style={S.hint}>12 = molto bassa · 48 = ottima · Media IT: 34.2 · Media SE: 40.1</div>
              <input type="range" min={12} max={48} step={1} value={ans.casp} onChange={e=>set("casp",+e.target.value)}
                style={{width:"100%", accentColor:"#10B981"}} />
              <div style={S.sliderRow}><span>12</span><span>48</span></div>
            </div>

            {/* Loneliness */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Solitudine percepita UCLA <span style={{color:"#8B5CF6", fontWeight:700}}>{ans.lonely}/9</span></div>
              <div style={S.hint}>3 = mai sola/solo · 9 = sempre sola/solo (scala a 3 item)</div>
              <input type="range" min={3} max={9} step={1} value={ans.lonely} onChange={e=>set("lonely",+e.target.value)}
                style={{width:"100%", accentColor:"#8B5CF6"}} />
              <div style={S.sliderRow}><span>3 — mai</span><span>9 — sempre</span></div>
            </div>

            {/* Hope */}
            <div style={{...S.card, marginBottom:10}}>
              <div style={S.label}>Ha speranza per il futuro?</div>
              <div style={{display:"flex", gap:8}}>
                {[["Sì — ha aspettative positive",1],["No — non vede prospettive",0]].map(([lb,v])=>(
                  <button key={v} onClick={()=>set("hope",v)} style={{...S.btn(ans.hope===v, "#10B981"), textAlign:"left", fontSize:"0.83rem"}}>
                    {lb}
                  </button>
                ))}
              </div>
            </div>

            {/* Income */}
            <div style={{...S.card, marginBottom:"1.5rem"}}>
              <div style={S.label}>Fascia di reddito familiare annuo</div>
              <div style={{display:"grid", gridTemplateColumns:"1fr 1fr", gap:7}}>
                {[["< €8.000",7.5],["€8.000 – 15.000",9.0],["€15.000 – 30.000",9.9],["> €30.000",10.5]].map(([lb,v])=>(
                  <button key={v} onClick={()=>set("income",v)} style={{...S.btn(ans.income===v, "#F59E0B"), fontSize:"0.83rem", textAlign:"left"}}>
                    {lb}
                  </button>
                ))}
              </div>
            </div>

            <div style={{display:"flex", gap:8}}>
              <button onClick={()=>go(2)} style={{...S.secondary, flex:"0 0 90px"}}>← Indietro</button>
              <button onClick={finish}
                style={{...S.primary(), flex:1, opacity:(ans.hope===null||ans.income===null)?0.45:1}}
                disabled={ans.hope===null||ans.income===null}>
                Classifica profilo 🔍
              </button>
            </div>
          </div>
        )}

        {/* ═══ SCREEN 4: RISULTATI ═══ */}
        {screen===4 && profile && (
          <div>
            {/* Profile header */}
            <div style={{textAlign:"center", marginBottom:"1.5rem"}}>
              <div style={{fontSize:"2.8rem", marginBottom:6}}>{profile.icon}</div>
              <div style={{display:"inline-block", background:profile.color+"22", color:profile.color, borderRadius:20, padding:"2px 12px", fontSize:"0.75rem", fontWeight:600, marginBottom:8}}>
                {profile.tag}
              </div>
              <h2 style={{fontSize:"1.65rem", fontWeight:700, color:profile.color, margin:"0 0 4px"}}>{profile.label}</h2>
              <div style={{color:"#475569", fontSize:"0.8rem"}}>{profile.pct} del campione · n={profile.n.toLocaleString()}</div>
            </div>

            {/* Description */}
            <div style={{...S.card, borderLeft:`4px solid ${profile.color}`, marginBottom:12}}>
              <p style={{color:"#CBD5E1", lineHeight:1.65, margin:0}}>{profile.desc}</p>
            </div>

            {/* Radar */}
            <div style={{...S.card, marginBottom:12}}>
              <div style={{fontSize:"0.75rem", fontWeight:600, color:"#475569", letterSpacing:"0.08em", marginBottom:12}}>
                PROFILO MULTIDIMENSIONALE (punteggio 0–100, più alto = migliore)
              </div>
              <ResponsiveContainer width="100%" height={220}>
                <RadarChart data={radar} margin={{top:5,right:20,bottom:5,left:20}}>
                  <PolarGrid stroke="#1E293B" />
                  <PolarAngleAxis dataKey="dim" tick={{fill:"#94A3B8", fontSize:11}} />
                  <Radar name="Paziente" dataKey="me" stroke={profile.color} fill={profile.color} fillOpacity={0.25} strokeWidth={2} />
                  <Radar name="Centroide profilo" dataKey="cp" stroke="#475569" fill="#475569" fillOpacity={0.08} strokeDasharray="5 4" strokeWidth={1.5} />
                </RadarChart>
              </ResponsiveContainer>
              <div style={{display:"flex", gap:20, justifyContent:"center", fontSize:"0.72rem", color:"#64748B"}}>
                <span><span style={{color:profile.color}}>━</span> Questo paziente</span>
                <span><span style={{color:"#475569"}}>╌</span> Centroide del profilo</span>
              </div>
            </div>

            {/* Scores table */}
            <div style={{...S.card, marginBottom:12}}>
              <div style={{fontSize:"0.75rem", fontWeight:600, color:"#475569", letterSpacing:"0.08em", marginBottom:10}}>
                PUNTEGGI PER DIMENSIONE
              </div>
              {radar.map(r=>(
                <div key={r.dim} style={{display:"flex", alignItems:"center", marginBottom:7, gap:10}}>
                  <div style={{width:90, fontSize:"0.78rem", color:"#94A3B8"}}>{r.dim}</div>
                  <div style={{flex:1, height:8, background:"#0F172A", borderRadius:4, overflow:"hidden"}}>
                    <div style={{height:"100%", width:`${r.me}%`, background:profile.color, borderRadius:4, transition:"width 0.6s ease"}} />
                  </div>
                  <div style={{width:32, fontSize:"0.78rem", color:"#CBD5E1", textAlign:"right"}}>{r.me}</div>
                  <div style={{width:32, fontSize:"0.72rem", color:"#475569", textAlign:"right"}}>/{r.cp}</div>
                </div>
              ))}
              <div style={{fontSize:"0.68rem", color:"#334155", marginTop:6}}>
                Formato: punteggio paziente / media centroide
              </div>
            </div>

            {/* Recommendations */}
            <div style={{...S.card, marginBottom:12}}>
              <div style={{fontSize:"0.75rem", fontWeight:600, color:"#475569", letterSpacing:"0.08em", marginBottom:12}}>
                RACCOMANDAZIONI DI INTERVENTO
              </div>
              {profile.recs.map((r,i)=>(
                <div key={i} style={{display:"flex", gap:10, marginBottom:9, alignItems:"flex-start"}}>
                  <div style={{minWidth:22, height:22, borderRadius:"50%", background:profile.color, color:"white", display:"flex",
                    alignItems:"center", justifyContent:"center", fontSize:"0.65rem", fontWeight:700}}>
                    {i+1}
                  </div>
                  <span style={{color:"#CBD5E1", fontSize:"0.88rem", lineHeight:1.55}}>{r}</span>
                </div>
              ))}
            </div>

            {/* Italy–Sweden comparison */}
            <div style={{...S.card, borderLeft:"4px solid #60A5FA", marginBottom:"1.75rem", background:"#172033"}}>
              <div style={{fontSize:"0.75rem", fontWeight:600, color:"#60A5FA", letterSpacing:"0.08em", marginBottom:8}}>
                🇮🇹 vs 🇸🇪 CONFRONTO CROSS-COUNTRY
              </div>
              <p style={{color:"#94A3B8", fontSize:"0.87rem", lineHeight:1.6, margin:0}}>{profile.se}</p>
            </div>

            <button onClick={reset} style={S.secondary}>← Nuova profilazione</button>
          </div>
        )}

      </div>

      {/* Footer */}
      <div style={{textAlign:"center", padding:"0.75rem", fontSize:"0.68rem", color:"#1E293B", borderTop:"1px solid #1E293B"}}>
        Silver Italy Profiler · Basato su SHARE Wave 9 release 9.0.0 · Bocconi University 2025
      </div>
    </div>
  );
}
