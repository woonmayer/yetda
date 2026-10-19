import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

// Timeline (30 fps): title → demo → features → end card.
const TITLE = 60;
const DEMO = 270;
const FEATURES = 90;
const END = 90;
export const PROMO_FRAMES = TITLE + DEMO + FEATURES + END;

const SANS = '-apple-system, "SF Pro Display", "Helvetica Neue", sans-serif';
const MONO = '"SF Mono", Menlo, monospace';
const ACCENT = '#ff9e45';
const BG = '#0d0e12';

const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
const ease = Easing.bezier(0.22, 1, 0.36, 1);
const fade = (f: number, from: number, to: number) => interpolate(f, [from, to], [0, 1], { ...clamp, easing: ease });

export const Promo = () => (
  <AbsoluteFill style={{ background: BG, fontFamily: SANS }}>
    <Sequence durationInFrames={TITLE}>
      <Title />
    </Sequence>
    <Sequence from={TITLE} durationInFrames={DEMO}>
      <Demo />
    </Sequence>
    <Sequence from={TITLE + DEMO} durationInFrames={FEATURES}>
      <Features />
    </Sequence>
    <Sequence from={TITLE + DEMO + FEATURES}>
      <EndCard />
    </Sequence>
  </AbsoluteFill>
);

// ─── Title ───────────────────────────────────────────────────────────────

const Title = () => {
  const f = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  const pop = spring({ frame: f, fps, config: { damping: 14 } });
  const out = interpolate(f, [48, 60], [1, 0], clamp);
  const size = width > 1500 ? 92 : 76;
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: out, textAlign: 'center', padding: 60 }}>
      <Img src={staticFile('icon.png')} style={{ width: 220, transform: `scale(${pop})` }} />
      <div style={{ color: '#fff', fontSize: size, fontWeight: 800, letterSpacing: '-0.035em', marginTop: 36, opacity: fade(f, 10, 25) }}>
        Screenshots into your coding agent
      </div>
      <div style={{ color: ACCENT, fontSize: size, fontWeight: 800, letterSpacing: '-0.035em', opacity: fade(f, 18, 33) }}>
        in one gesture.
      </div>
    </AbsoluteFill>
  );
};

// ─── Demo ────────────────────────────────────────────────────────────────

// The demo is laid out on a fixed 1600×1000 stage, scaled to fit the frame.
const STAGE_W = 1600;
const STAGE_H = 1000;
const SELECTION = { x: 84, y: 298, w: 872, h: 150 }; // around the error message
const QUESTION = 'why is this broken?';
const ANSWER = [
  '⏺ `items` is undefined on the first render — the',
  '  fetch hasn\'t resolved yet. Default it to an empty',
  '  array: const [items, setItems] = useState([])',
];

// Beats, in demo-local frames.
const TAP1 = 18, TAP2 = 28, SELECT_START = 55, SELECT_END = 95, SHOT = 100;
const FRONT = 108, PASTE = 122, TYPE_START = 134, TYPE_END = 170, ENTER = 180, ANSWER_START = 192;

const Demo = () => {
  const f = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;

  const stageScale = vertical ? (width * 0.96) / STAGE_W : Math.min((width * 0.8) / STAGE_W, (height * 0.78) / STAGE_H);
  const zoom = interpolate(f, [FRONT, FRONT + 25], [1, 1.28], { ...clamp, easing: ease });
  const panX = interpolate(f, [FRONT, FRONT + 25], [0, -300], { ...clamp, easing: ease });
  const panY = interpolate(f, [FRONT, FRONT + 25], [0, -150], { ...clamp, easing: ease });
  const enter = fade(f, 0, 14);
  const exit = interpolate(f, [DEMO - 12, DEMO], [1, 0], clamp);

  const caption =
    f < SELECT_START ? 'Tap ⌘ twice' : f < FRONT ? 'Drag a region' : f < ENTER ? 'It\'s already in the prompt' : 'Ask away';
  const captionKey = f < SELECT_START ? 0 : f < FRONT ? SELECT_START : f < ENTER ? FRONT : ENTER;

  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: enter * exit, flexDirection: 'column' }}>
      {vertical && <Caption text={caption} startFrame={captionKey} size={68} />}
      <div style={{ width: STAGE_W * stageScale, height: STAGE_H * stageScale, borderRadius: 28 * stageScale, overflow: 'hidden', boxShadow: '0 40px 100px rgba(0,0,0,.6)', margin: vertical ? '60px 0' : 0 }}>
        <div style={{ width: STAGE_W, height: STAGE_H, transform: `scale(${stageScale})`, transformOrigin: 'top left' }}>
          <div style={{ position: 'absolute', inset: 0, transform: `translate(${panX}px, ${panY}px) scale(${zoom})`, transformOrigin: 'center' }}>
            <Desktop f={f} />
          </div>
        </div>
      </div>
      {!vertical && (
        <div style={{ position: 'absolute', bottom: 34 }}>
          <Caption text={caption} startFrame={captionKey} size={46} />
        </div>
      )}
    </AbsoluteFill>
  );
};

const Caption = ({ text, startFrame, size }: { text: string; startFrame: number; size: number }) => {
  const f = useCurrentFrame();
  const t = fade(f, startFrame, startFrame + 10);
  return (
    <div style={{ color: '#fff', fontSize: size, fontWeight: 700, letterSpacing: '-0.02em', opacity: t, transform: `translateY(${(1 - t) * 14}px)`, textAlign: 'center' }}>
      {text}
    </div>
  );
};

const Desktop = ({ f }: { f: number }) => {
  const termFront = f >= FRONT;
  const selecting = f >= SELECT_START && f < SHOT;
  const sel = interpolate(f, [SELECT_START + 5, SELECT_END], [0, 1], { ...clamp, easing: ease });
  const flash = interpolate(f, [SHOT, SHOT + 3, SHOT + 12], [0, 0.7, 0], clamp);
  const termPop = termFront ? interpolate(f, [FRONT, FRONT + 6, FRONT + 14], [1, 1.03, 1], clamp) : 1;

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, #3b3f8f, #8a4f9e 55%, #e0806b)' }}>
      <MenuBar f={f} />
      <Window x={70} y={110} w={900} h={640} z={termFront ? 1 : 2} light>
        <div style={{ padding: 32 }}>
          <div style={{ height: 26, width: '55%', background: '#1f2330', borderRadius: 6, marginBottom: 26 }} />
          <div style={{ height: 14, width: '90%', background: '#e3e5ea', borderRadius: 7, marginBottom: 14 }} />
          <div style={{ height: 14, width: '72%', background: '#e3e5ea', borderRadius: 7 }} />
          <div style={{ marginTop: 34, padding: '20px 22px', borderRadius: 10, border: '2px solid #f3b4b4', background: '#fff1f1', color: '#c0392b', font: `600 24px/1.45 ${MONO}` }}>
            TypeError: Cannot read properties of undefined (reading 'map')
          </div>
          <div style={{ marginTop: 30, width: 260, height: 52, borderRadius: 10, background: '#4f63ff' }} />
        </div>
      </Window>
      <Window x={700} y={400} w={840} h={540} z={termFront ? 2 : 1} scale={termPop}>
        <Terminal f={f} />
      </Window>

      {selecting && <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.28)', zIndex: 5 }} />}
      {selecting && f >= SELECT_START + 5 && (
        <div
          style={{
            position: 'absolute', zIndex: 6,
            left: SELECTION.x, top: SELECTION.y,
            width: SELECTION.w * sel, height: SELECTION.h * sel,
            border: '3px solid #fff', background: 'rgba(255,255,255,.14)', boxShadow: '0 0 0 1px rgba(0,0,0,.3)',
          }}
        />
      )}
      <div style={{ position: 'absolute', inset: 0, background: '#fff', opacity: flash, zIndex: 9 }} />
      <KeyCast f={f} />
    </div>
  );
};

const MenuBar = ({ f }: { f: number }) => {
  const count = f >= SHOT ? ' 1' : '';
  return (
    <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 40, background: 'rgba(20,20,30,.35)', backdropFilter: 'blur(20px)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 26, padding: '0 26px', color: '#fff', font: `500 20px ${SANS}`, zIndex: 8 }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <Img src={staticFile('icon.png')} style={{ width: 26 }} />
        {count}
      </span>
      <span>Mon 9:41 AM</span>
    </div>
  );
};

const Window = ({ x, y, w, h, z, light, scale = 1, children }: {
  x: number; y: number; w: number; h: number; z: number; light?: boolean; scale?: number; children: React.ReactNode;
}) => (
  <div style={{ position: 'absolute', left: x, top: y, width: w, height: h, zIndex: z, borderRadius: 18, overflow: 'hidden', background: light ? '#fff' : '#14151b', boxShadow: '0 30px 70px rgba(0,0,0,.4)', transform: `scale(${scale})` }}>
    <div style={{ height: 46, background: light ? '#ececec' : '#22242c', display: 'flex', alignItems: 'center', gap: 10, padding: '0 18px' }}>
      {['#ff5f57', '#febc2e', '#28c840'].map((c) => <div key={c} style={{ width: 16, height: 16, borderRadius: 8, background: c }} />)}
    </div>
    {children}
  </div>
);

const Terminal = ({ f }: { f: number }) => {
  const pasted = f >= PASTE;
  const pastePop = spring({ frame: f - PASTE, fps: 30, config: { damping: 12 } });
  const typed = QUESTION.slice(0, Math.round(interpolate(f, [TYPE_START, TYPE_END], [0, QUESTION.length], clamp)));
  const sent = f >= ENTER;
  const cursorOn = Math.floor(f / 15) % 2 === 0;
  const lines = Math.floor(interpolate(f, [ANSWER_START, ANSWER_START + 36], [0, ANSWER.length], clamp));

  return (
    <div style={{ padding: '22px 26px', color: '#d8dae3', font: `24px/1.6 ${MONO}` }}>
      <div><span style={{ color: ACCENT }}>●</span> agent</div>
      <div style={{ color: '#6e7386' }}>  cwd: ~/projects/webapp</div>
      {sent && (
        <div style={{ marginTop: 18 }}>
          <span style={{ color: '#6e7386' }}>&gt; </span>
          <span style={{ color: '#8fb4ff' }}>[Image #1]</span> {QUESTION}
        </div>
      )}
      {sent && ANSWER.slice(0, lines).map((l, i) => (
        <div key={i} style={{ whiteSpace: 'pre', marginTop: i === 0 ? 14 : 0 }}>{l}</div>
      ))}
      <div style={{ marginTop: 18, border: '2px solid #3a3d4a', borderRadius: 10, padding: '10px 16px', whiteSpace: 'pre' }}>
        &gt;{' '}
        {!sent && pasted && (
          <span style={{ color: '#8fb4ff', display: 'inline-block', transform: `scale(${pastePop})` }}>[Image #1] </span>
        )}
        {!sent && typed}
        <span style={{ display: 'inline-block', width: 13, height: 28, verticalAlign: 'text-bottom', background: cursorOn ? '#d8dae3' : 'transparent' }} />
      </div>
    </div>
  );
};

// On-screen keystroke badges for the two ⌘ taps.
const KeyCast = ({ f }: { f: number }) => {
  if (f < TAP1 - 2 || f > SELECT_START + 4) return null;
  const out = interpolate(f, [SELECT_START - 6, SELECT_START + 4], [1, 0], clamp);
  const key = (tap: number) => {
    const shown = f >= tap;
    const press = interpolate(f, [tap, tap + 3, tap + 7], [1, 0.88, 1], clamp);
    return (
      <div style={{ opacity: shown ? 1 : 0, transform: `scale(${press})`, width: 130, height: 130, borderRadius: 26, background: 'rgba(20,20,28,.85)', color: '#fff', font: `600 72px ${SANS}`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 20px 50px rgba(0,0,0,.4)' }}>
        ⌘
      </div>
    );
  };
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: 560, display: 'flex', justifyContent: 'center', gap: 22, zIndex: 10, opacity: out }}>
      {key(TAP1)}
      {key(TAP2)}
    </div>
  );
};

// ─── Features ────────────────────────────────────────────────────────────

const FEATURE_LINES: [string, string][] = [
  ['⌘⌘', 'Capture from anywhere'],
  ['↩︎', 'Auto-pastes into your terminal'],
  ['⌘⇧1', 'Paste any of your last 10 shots'],
];

const Features = () => {
  const f = useCurrentFrame();
  const { width } = useVideoConfig();
  const size = width > 1500 ? 64 : 54;
  const exit = interpolate(f, [FEATURES - 10, FEATURES], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: exit }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 44 }}>
        {FEATURE_LINES.map(([key, label], i) => {
          const t = fade(f, 4 + i * 12, 18 + i * 12);
          return (
            <div key={key} style={{ display: 'flex', alignItems: 'center', gap: 36, opacity: t, transform: `translateX(${(1 - t) * -40}px)` }}>
              <div style={{ minWidth: size * 2.8, padding: '10px 22px', borderRadius: 18, border: '2px solid #2c2e3a', background: '#181a21', color: ACCENT, font: `700 ${size * 0.8}px ${SANS}`, textAlign: 'center' }}>
                {key}
              </div>
              <div style={{ color: '#fff', fontSize: size, fontWeight: 700, letterSpacing: '-0.025em' }}>{label}</div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

// ─── End card ────────────────────────────────────────────────────────────

const EndCard = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: f, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
      <Img src={staticFile('icon.png')} style={{ width: 200, transform: `scale(${pop})` }} />
      <div style={{ color: '#fff', fontSize: 96, fontWeight: 800, letterSpacing: '-0.04em', marginTop: 28, opacity: fade(f, 6, 20) }}>Yetda</div>
      <div style={{ color: '#9a9cab', fontSize: 34, marginTop: 10, opacity: fade(f, 10, 24) }}>옜다 · Korean for “here, take it.”</div>
      <div style={{ color: '#9a9cab', fontSize: 30, marginTop: 8, opacity: fade(f, 14, 28) }}>Free &amp; open source for macOS</div>
      <div style={{ color: '#d8dae3', fontSize: 30, marginTop: 26, opacity: fade(f, 18, 32) }}>Claude Code · Codex · Gemini CLI · opencode</div>
      <div style={{ color: ACCENT, font: `500 34px ${MONO}`, marginTop: 34, opacity: fade(f, 22, 36) }}>github.com/woonmayer/yetda</div>
    </AbsoluteFill>
  );
};
