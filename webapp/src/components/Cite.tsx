import { useEffect, useId, useRef, useState } from 'react';

/**
 * <Cite> — inline citation tooltip for evidence numbers.
 *
 * Renders `children` (typically a number) with a dotted underline. On hover
 * (desktop) or click (any device), a small popover shows:
 *   • a one-line description of WHAT the number measures (`metric`)
 *   • the underlying source / thesis reference (`source`)
 *
 * Behaviour:
 *   - Hover → opens transient (closes on mouseleave).
 *   - Click → pins the popover open (closes on outside click or Escape).
 *   - Keyboard: focusable button, aria-describedby links to the popover.
 */
type CiteProps = {
  children: React.ReactNode;
  metric: string;
  source: string;
};

export function Cite({ children, metric, source }: CiteProps) {
  const [pinned, setPinned] = useState(false);
  const [hovered, setHovered] = useState(false);
  const wrapperRef = useRef<HTMLSpanElement>(null);
  const tooltipId = useId();

  // Close pinned tooltip on outside click or Escape
  useEffect(() => {
    if (!pinned) return;
    const onMouseDown = (e: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) {
        setPinned(false);
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPinned(false);
    };
    document.addEventListener('mousedown', onMouseDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onMouseDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [pinned]);

  const open = pinned || hovered;

  return (
    <span
      ref={wrapperRef}
      className="relative inline-block"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          setPinned((p) => !p);
        }}
        onFocus={() => setHovered(true)}
        onBlur={() => setHovered(false)}
        aria-describedby={open ? tooltipId : undefined}
        aria-expanded={open}
        className="font-semibold text-slate-900 underline decoration-dotted decoration-zinc-400 underline-offset-4 hover:decoration-blue-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 rounded-sm cursor-help bg-transparent border-0 p-0 m-0 inline"
      >
        {children}
      </button>

      {open && (
        <span
          id={tooltipId}
          role="tooltip"
          className="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 w-72 max-w-[calc(100vw-2rem)] rounded-lg bg-slate-900 text-white text-xs leading-relaxed p-3 shadow-xl animate-fade-in"
        >
          <span className="block font-medium text-white">{metric}</span>
          <span className="block text-zinc-300 font-mono text-[10px] mt-1.5 tracking-wide">
            {source}
          </span>
          <span
            aria-hidden="true"
            className="absolute top-full left-1/2 -translate-x-1/2 -mt-[3px] w-2 h-2 bg-slate-900 rotate-45"
          />
        </span>
      )}
    </span>
  );
}
