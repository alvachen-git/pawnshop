import { useEffect, useRef, useState } from 'react';

const choices = [
  { id: 'new', label: '开启新游戏' },
  { id: 'load', label: '读取游戏' },
  { id: 'exit', label: '离开游戏' },
];

export function App() {
  const [hovered, setHovered] = useState(null);
  const [focused, setFocused] = useState(null);
  const [pressed, setPressed] = useState(null);
  const [announcement, setAnnouncement] = useState('');
  const [ready, setReady] = useState(false);
  const [error, setError] = useState(false);
  const buttons = useRef([]);
  const pressTimer = useRef();
  const active = hovered ?? focused;
  useEffect(() => () => clearTimeout(pressTimer.current), []);

  function activate(choice) {
    clearTimeout(pressTimer.current);
    setPressed(choice.id);
    setAnnouncement(`已选择${choice.label}`);
    // Isolated motion prototype; does not modify saves or close the browser.
    window.dispatchEvent(new CustomEvent('pawnbroker:menu-action', {
      detail: { action: choice.id },
    }));
    pressTimer.current = setTimeout(() => setPressed(null), 720);
  }

  function navigate(event, index) {
    let next;
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight') next = (index + 1) % 3;
    if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') next = (index + 2) % 3;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = 2;
    if (event.key === 'Escape') {
      event.currentTarget.blur();
      setFocused(null);
      setHovered(null);
    }
    if (next !== undefined) {
      event.preventDefault();
      buttons.current[next]?.focus();
    }
  }

  return (
    <main className="preview-shell">
      <section className={`menu-scene ${ready ? 'is-ready' : ''} ${active ? 'is-haunted' : ''} ${pressed ? 'is-pressed' : ''}`} aria-label="鬼市当铺主画面" data-active={active ?? ''} data-pressed={pressed ?? ''}>
        <h1 className="sr-only">鬼市当铺</h1>
        <img className="scene-art" src="/assets/menu-background.png" alt="雨夜里的旧当铺，木门半开，暖光落在湿石板上。" onLoad={() => setReady(true)} onError={() => setError(true)} draggable="false" />
        <img className="door-afterimage" src="/assets/menu-background.png" alt="" aria-hidden="true" draggable="false" />
        <nav className="menu-choices" aria-label="游戏菜单">
          {choices.map((choice, index) => (
            <button key={choice.id} ref={el => buttons.current[index] = el} type="button"
              className={`menu-button ${index === 0 ? 'primary' : ''} ${active === choice.id ? 'is-active' : ''} ${pressed === choice.id ? 'is-pressed' : ''}`}
              data-action={choice.id} aria-label={choice.label}
              onPointerEnter={event => event.pointerType !== 'touch' && setHovered(choice.id)}
              onPointerLeave={() => setHovered(null)} onFocus={event => setFocused(event.currentTarget.matches(':focus-visible') ? choice.id : null)} onBlur={() => setFocused(null)}
              onClick={() => activate(choice)} onKeyDown={event => navigate(event, index)}>
              <span className="plaque" aria-hidden="true" />
              <span className="seal-echo" aria-hidden="true" />
              <span className="button-label">{choice.label}</span>
              <span className="ink-echo" aria-hidden="true">{choice.label}</span>
            </button>
          ))}
        </nav>
        {error && <p className="asset-error" role="alert">画面载入失败，请刷新重试。</p>}
        <p className="sr-only" aria-live="polite">{announcement}</p>
      </section>
    </main>
  );
}
