import { createRoot } from 'react-dom/client';

function App() {
  const APP_STORE_URL = 'https://apps.apple.com/app/socialstar-photo-competitions/id6473705189';

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700;9..40,800&display=swap');

        :root {
          --bg: #F8F8F6; --card: #EFEEEB; --card-alt: #E8E7E3;
          --text: #3F3F3C; --muted: #8A8A86;
          --accent: #C15F3C; --accent-dk: #A34E2F;
          --green: #2A9D5C; --divider: rgba(0,0,0,0.07);
        }
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { scroll-behavior: smooth; }
        body { font-family: 'DM Sans', sans-serif; background: var(--bg); color: var(--text); -webkit-font-smoothing: antialiased; overflow-x: hidden; }

        nav {
          position: sticky; top: 0; z-index: 100; background: var(--bg);
          border-bottom: 1px solid var(--divider); padding: 0 24px; height: 60px;
          display: flex; align-items: center; justify-content: space-between;
        }
        .nav-brand { display: flex; align-items: center; gap: 10px; text-decoration: none; }
        .nav-brand span { font-size: 20px; font-weight: 800; color: var(--text); letter-spacing: -0.5px; }
        .nav-cta {
          background: var(--accent); color: white; text-decoration: none;
          padding: 9px 20px; border-radius: 100px; font-size: 14px; font-weight: 600; transition: background 0.2s; border: none; cursor: pointer;
          display: inline-flex; align-items: center; gap: 6px;
        }
        .nav-cta:hover { background: var(--accent-dk); }

        .hero { padding: 72px 24px 80px; text-align: center; max-width: 680px; margin: 0 auto; }
        .hero-badge {
          display: inline-flex; align-items: center; gap: 7px;
          background: var(--card); border: 1px solid var(--divider); border-radius: 100px;
          padding: 6px 14px; font-size: 13px; color: var(--muted); font-weight: 500;
          margin-bottom: 28px; animation: fadeUp 0.5s ease both;
        }
        .hero-badge .dot { width: 6px; height: 6px; border-radius: 50%; background: var(--green); }
        .hero h1 {
          font-size: clamp(48px, 10vw, 80px);
          font-weight: 800; line-height: 1.05; letter-spacing: -2.5px; color: var(--text);
          margin-bottom: 24px; animation: fadeUp 0.5s 0.1s ease both;
        }
        .hero h1 em { font-style: italic; color: var(--accent); }
        .hero p {
          font-size: 18px; color: var(--muted); line-height: 1.65; max-width: 440px;
          margin: 0 auto 40px; font-weight: 400; animation: fadeUp 0.5s 0.2s ease both;
        }

        .cta-section { animation: fadeUp 0.5s 0.3s ease both; }
        .app-store-btn {
          display: inline-flex; align-items: center; gap: 10px;
          background: var(--accent); color: white; text-decoration: none;
          padding: 16px 32px; border-radius: 100px; font-size: 17px; font-weight: 600;
          font-family: 'DM Sans', sans-serif; transition: background 0.2s, transform 0.15s;
          border: none; cursor: pointer;
        }
        .app-store-btn:hover { background: var(--accent-dk); transform: translateY(-2px); }
        .app-store-btn svg { width: 24px; height: 24px; }
        .cta-note { font-size: 14px; color: var(--muted); margin-top: 16px; }
        .cta-note a { color: var(--accent); text-decoration: none; font-weight: 500; }
        .cta-note a:hover { text-decoration: underline; }

        .mockup-strip { width: 100%; overflow: hidden; padding: 0 24px 80px; }
        .mockup-inner { max-width: 680px; margin: 0 auto; display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .mockup-card { background: var(--card); border-radius: 20px; overflow: hidden; aspect-ratio: 9/16; position: relative; border: 1px solid var(--divider); animation: fadeUp 0.6s ease both; }
        .mockup-card:nth-child(2) { animation-delay: 0.1s; }
        .mockup-card:nth-child(3) { animation-delay: 0.2s; }
        .mockup-card .screen-header { padding: 16px 14px 10px; border-bottom: 1px solid var(--divider); }
        .screen-title { font-size: 11px; font-weight: 700; color: var(--text); letter-spacing: 0.3px; }
        .screen-sub { font-size: 9px; color: var(--muted); margin-top: 2px; }

        .mockup-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; padding: 10px 10px 0; }
        .mock-photo { border-radius: 10px; aspect-ratio: 3/4; display: flex; flex-direction: column; justify-content: flex-end; padding: 6px; position: relative; overflow: hidden; }
        .mock-photo-bg { position: absolute; inset: 0; border-radius: 10px; }
        .mock-photo-label { position: relative; font-size: 8px; font-weight: 700; color: white; }
        .mock-fee { position: relative; font-size: 7px; font-weight: 700; color: white; background: var(--green); border-radius: 100px; padding: 2px 5px; align-self: flex-end; margin-top: 2px; display: inline-block; }
        .mock-add-card { border-radius: 10px; aspect-ratio: 3/4; border: 1.5px dashed; border-color: rgba(193,95,60,0.4); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; }
        .mock-add-icon { width: 18px; height: 18px; background: var(--accent); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px; font-weight: 700; line-height: 1; }
        .mock-add-text { font-size: 8px; font-weight: 600; color: var(--accent); }
        .mock-bottom-bar { padding: 8px 10px 10px; display: flex; justify-content: flex-end; }
        .mock-start-btn { background: var(--accent); color: white; font-size: 8px; font-weight: 700; border-radius: 100px; padding: 5px 12px; }

        .judging-screen { background: var(--accent); height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; padding: 20px; }
        .judging-rings { position: relative; width: 70px; height: 70px; display: flex; align-items: center; justify-content: center; background: transparent; }
        .ring { position: absolute; border-radius: 50%; border: 1px solid rgba(255,255,255,0.25); }
        .ring-1 { width: 70px; height: 70px; }
        .ring-2 { width: 48px; height: 48px; }
        .ring-3 { width: 26px; height: 26px; }
        .ring-core { width: 22px; height: 22px; background: rgba(255,255,255,0.95); border-radius: 50%; }
        .judging-label { color: white; font-size: 11px; font-weight: 600; text-align: center; }
        .judging-sub { color: rgba(255,255,255,0.65); font-size: 9px; text-align: center; }
        .judging-dots { display: flex; gap: 4px; }
        .judging-dot { width: 4px; height: 4px; border-radius: 50%; background: rgba(255,255,255,0.3); }
        .judging-dot:nth-child(1) { background: white; }

        .results-screen { padding: 10px; display: flex; flex-direction: column; gap: 6px; }
        .result-winner-banner { background: var(--card-alt); border-radius: 10px; padding: 8px 10px; text-align: center; }
        .result-winner-text { font-size: 10px; font-weight: 700; color: var(--text); }
        .result-payout { font-size: 9px; font-weight: 700; color: var(--green); background: rgba(42,157,92,0.1); border-radius: 100px; padding: 2px 8px; display: inline-block; margin-top: 3px; }
        .result-row { display: flex; align-items: center; gap: 6px; background: var(--card); border-radius: 10px; padding: 7px 8px; }
        .result-rank { font-size: 9px; font-weight: 700; color: var(--muted); width: 12px; }
        .result-rank.gold { color: #DAA520; }
        .result-thumb { width: 26px; height: 32px; border-radius: 5px; flex-shrink: 0; }
        .result-info { flex: 1; min-width: 0; }
        .result-name { font-size: 8px; font-weight: 700; color: var(--text); }
        .result-reason { font-size: 7px; color: var(--muted); margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .result-score { font-size: 13px; font-weight: 900; color: #DAA520; }

        .how { padding: 80px 24px; max-width: 680px; margin: 0 auto; }
        .section-label { font-size: 12px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; color: var(--accent); margin-bottom: 12px; }
        .section-heading { font-size: clamp(30px, 6vw, 46px); font-weight: 800; line-height: 1.1; letter-spacing: -1.5px; color: var(--text); margin-bottom: 48px; }
        .steps { display: flex; flex-direction: column; gap: 2px; }
        .step { display: flex; gap: 20px; align-items: flex-start; padding: 28px 0; border-bottom: 1px solid var(--divider); }
        .step:last-child { border-bottom: none; }
        .step-num { width: 40px; height: 40px; border-radius: 12px; background: var(--card); border: 1px solid var(--divider); display: flex; align-items: center; justify-content: center; font-size: 18px; font-weight: 700; color: var(--accent); flex-shrink: 0; }
        .step-body { flex: 1; }
        .step-title { font-size: 17px; font-weight: 600; color: var(--text); margin-bottom: 6px; letter-spacing: -0.2px; }
        .step-desc { font-size: 15px; color: var(--muted); line-height: 1.6; }

        .final-cta { background: var(--accent); margin: 0 16px 80px; border-radius: 24px; padding: 56px 32px; text-align: center; overflow: hidden; position: relative; }
        .final-cta::before { content: ''; position: absolute; top: -60px; right: -60px; width: 200px; height: 200px; border-radius: 50%; background: rgba(255,255,255,0.05); }
        .final-cta::after { content: ''; position: absolute; bottom: -40px; left: -40px; width: 160px; height: 160px; border-radius: 50%; background: rgba(255,255,255,0.05); }
        .final-cta h2 { font-size: clamp(28px, 7vw, 46px); font-weight: 800; line-height: 1.1; letter-spacing: -1.5px; color: white; margin-bottom: 14px; position: relative; z-index: 1; }
        .final-cta p { font-size: 16px; color: rgba(255,255,255,0.75); margin-bottom: 32px; position: relative; z-index: 1; }
        .final-cta .cta-section { position: relative; z-index: 1; }
        .final-cta .app-store-btn { background: white; color: var(--accent); }
        .final-cta .app-store-btn:hover { background: rgba(255,255,255,0.92); }
        .final-cta .cta-note { color: rgba(255,255,255,0.55); }
        .final-cta .cta-note a { color: white; }

        footer { border-top: 1px solid var(--divider); padding: 28px 24px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; }
        .footer-brand { display: flex; align-items: center; gap: 8px; text-decoration: none; }
        .footer-brand span { font-size: 15px; font-weight: 700; color: var(--text); }
        .footer-links { display: flex; gap: 20px; align-items: center; }
        .footer-links a { font-size: 13px; color: var(--muted); text-decoration: none; transition: color 0.2s; }
        .footer-links a:hover { color: var(--text); }
        .footer-right { font-size: 12px; color: var(--muted); }

        @keyframes fadeUp { from { opacity: 0; transform: translateY(18px); } to { opacity: 1; transform: translateY(0); } }
        @media (max-width: 500px) {
          .hero { padding: 52px 20px 56px; }
          .mockup-inner { gap: 8px; }
          .how { padding: 56px 20px; }
          .final-cta { margin: 0 12px 60px; padding: 44px 24px; }
          footer { flex-direction: column; align-items: flex-start; }
          .footer-links { gap: 14px; }
        }
      `}</style>

      <nav>
        <a href="#" className="nav-brand">
          <img src="https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c-us/o/static%2Fstar-2.png?alt=media&token=5307cd18-57af-4eda-85ab-b48e3efb954a" alt="SocialStar" style={{width: '32px', height: '32px'}} />
          <span>SocialStar</span>
        </a>
        <a href={APP_STORE_URL} className="nav-cta" target="_blank" rel="noopener noreferrer">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
          Download
        </a>
      </nav>

      <section className="hero">
        <div className="hero-badge"><span className="dot"></span>Now live on the App Store</div>
        <h1>Photo comps<br />with your <em>crew</em></h1>
        <p>Pick a theme, submit your shot, let AI pick the winner. Bragging rights and real prizes in minutes.</p>

        <div className="cta-section">
          <a href={APP_STORE_URL} className="app-store-btn" target="_blank" rel="noopener noreferrer">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
            Download on the App Store
          </a>
          <div className="cta-note">Free to download. Available now.</div>
        </div>
      </section>

      {/* Keep the mockup strip as-is - it shows what the app does */}
      <div className="mockup-strip">
        <div className="mockup-inner">
          <div className="mockup-card">
            <div className="screen-header">
              <div className="screen-title">Lobby</div>
              <div className="screen-sub">Outfit of the Day · $2.00</div>
            </div>
            <div className="mockup-grid">
              <div className="mock-photo">
                <div className="mock-photo-bg" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F97509ae7fcd7ffedfbe7c010f1602d0c-min.jpg?alt=media&token=fe79998e-8a9f-45f2-8d42-c2f9677131fb)', backgroundSize: 'cover', backgroundPosition: 'center'}}></div>
                <span className="mock-photo-label">You</span>
                <span className="mock-fee">$1.00</span>
              </div>
              <div className="mock-photo">
                <div className="mock-photo-bg" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F9f0efe5a61c7e766838c49e18d70dfd0-2-min.jpg?alt=media&token=72aaa156-75f9-4117-84f1-6f969bb3e657)', backgroundSize: 'cover', backgroundPosition: 'center'}}></div>
                <span className="mock-photo-label">Jamie</span>
                <span className="mock-fee">$1.00</span>
              </div>
              <div className="mock-photo">
                <div className="mock-photo-bg" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F00e95ee3819ad001f7455d3e34e085c6-2-min.jpg?alt=media&token=3f34b56d-03b0-442c-abcc-6b6bd907e94e)', backgroundSize: 'cover', backgroundPosition: 'center'}}></div>
                <span className="mock-photo-label">Sarah</span>
                <span className="mock-fee">$1.00</span>
              </div>
              <div className="mock-add-card">
                <div className="mock-add-icon">+</div>
                <span className="mock-add-text">Join Round</span>
              </div>
            </div>
            <div className="mock-bottom-bar">
              <div className="mock-start-btn">Start Round</div>
            </div>
          </div>

          <div className="mockup-card">
            <div className="judging-screen">
              <div className="judging-rings">
                <svg width="70" height="70" viewBox="0 0 70 70" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <circle cx="35" cy="35" r="34" stroke="rgba(255,255,255,0.2)" strokeWidth="1"/>
                  <circle cx="35" cy="35" r="23" stroke="rgba(255,255,255,0.25)" strokeWidth="1"/>
                  <circle cx="35" cy="35" r="11" fill="rgba(255,255,255,0.95)"/>
                </svg>
              </div>
              <div className="judging-label">AI is judging</div>
              <div className="judging-sub">Outfit of the Day</div>
              <div className="judging-dots">
                <div className="judging-dot"></div>
                <div className="judging-dot"></div>
                <div className="judging-dot"></div>
              </div>
            </div>
          </div>

          <div className="mockup-card">
            <div className="screen-header">
              <div className="screen-title">Results</div>
              <div className="screen-sub">Outfit of the Day</div>
            </div>
            <div className="results-screen">
              <div className="result-winner-banner">
                <div className="result-winner-text">Jamie wins! 🏆</div>
                <div className="result-payout">+$2.70</div>
              </div>
              <div className="result-row">
                <div className="result-rank gold">1</div>
                <div className="result-thumb" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F9f0efe5a61c7e766838c49e18d70dfd0-2-min.jpg?alt=media&token=72aaa156-75f9-4117-84f1-6f969bb3e657)', backgroundSize: 'cover', backgroundPosition: 'center', borderRadius: '5px'}}></div>
                <div className="result-info">
                  <div className="result-name">Jamie</div>
                  <div className="result-reason">Clean fit, great colours</div>
                </div>
                <div className="result-score">9.1</div>
              </div>
              <div className="result-row">
                <div className="result-rank">2</div>
                <div className="result-thumb" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F97509ae7fcd7ffedfbe7c010f1602d0c-min.jpg?alt=media&token=fe79998e-8a9f-45f2-8d42-c2f9677131fb)', backgroundSize: 'cover', backgroundPosition: 'center', borderRadius: '5px'}}></div>
                <div className="result-info">
                  <div className="result-name">You</div>
                  <div className="result-reason">Solid effort, good theme fit</div>
                </div>
                <div className="result-score" style={{color: 'var(--muted)', fontSize: '11px', fontWeight: 700}}>7.4</div>
              </div>
              <div className="result-row">
                <div className="result-rank">3</div>
                <div className="result-thumb" style={{backgroundImage: 'url(https://firebasestorage.googleapis.com/v0/b/ss-web-rate.firebasestorage.app/o/compress%2F00e95ee3819ad001f7455d3e34e085c6-2-min.jpg?alt=media&token=3f34b56d-03b0-442c-abcc-6b6bd907e94e)', backgroundSize: 'cover', backgroundPosition: 'center', borderRadius: '5px'}}></div>
                <div className="result-info">
                  <div className="result-name">Sarah</div>
                  <div className="result-reason">Off theme, nice pic though</div>
                </div>
                <div className="result-score" style={{color: 'var(--muted)', fontSize: '11px', fontWeight: 700}}>5.2</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <section className="how">
        <div className="section-label">How it works</div>
        <div className="section-heading">Three steps.<br />Endless bragging rights.</div>
        <div className="steps">
          <div className="step">
            <div className="step-num">1</div>
            <div className="step-body">
              <div className="step-title">Pick a theme</div>
              <div className="step-desc">Choose from your group's saved themes — outfits, selfies, food, vibes — or create a new one on the fly. Everyone knows the brief.</div>
            </div>
          </div>
          <div className="step">
            <div className="step-num">2</div>
            <div className="step-body">
              <div className="step-title">Submit your shot</div>
              <div className="step-desc">Snap a fresh one or dig out a gem from your camera roll. Add an optional entry fee to the prize pot — more skin in the game, more fun.</div>
            </div>
          </div>
          <div className="step">
            <div className="step-num">3</div>
            <div className="step-body">
              <div className="step-title">AI judges the winner</div>
              <div className="step-desc">Gemini scores every photo on theme fit and quality. Honest, fast, and nobody can accuse their mate of bias. Winnings go straight to your wallet.</div>
            </div>
          </div>
        </div>
      </section>

      <div className="final-cta">
        <h2>Ready to play?</h2>
        <p>Download SocialStar now and start competing with your crew.</p>
        <div className="cta-section">
          <a href={APP_STORE_URL} className="app-store-btn" target="_blank" rel="noopener noreferrer">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
            Download on the App Store
          </a>
          <div className="cta-note">Free to download. Available now.</div>
        </div>
      </div>

      <footer>
        <a href="#" className="footer-brand">
          <img src="https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c-us/o/static%2Fstar-2.png?alt=media&token=5307cd18-57af-4eda-85ab-b48e3efb954a" alt="SocialStar" style={{width: '24px', height: '24px'}} />
          <span>SocialStar</span>
        </a>
        <div className="footer-links">
          <a href="mailto:info@socialstarapp.com">Contact</a>
          <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">App Store</a>
        </div>
        <div className="footer-right">© 2026 SocialStar</div>
      </footer>
    </>
  );
}

const root = createRoot(document.getElementById('root'));
root.render(<App />);