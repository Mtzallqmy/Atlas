"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import gsap from "gsap";
import {
  ArrowRight,
  BookOpen,
  Bookmark,
  BrainCircuit,
  ChevronDown,
  CircleHelp,
  Compass,
  FileText,
  Heart,
  LibraryBig,
  Microscope,
  NotebookPen,
  Play,
  Search,
  Share2,
  Sparkles,
  Stethoscope,
  X,
} from "lucide-react";
import { OrganViewer } from "./OrganViewer";
import { LearningHub } from "./LearningHub";
import { organById, organs, type Organ, type OrganId } from "../lib/anatomy-data";
import { localizeOrgan, ui, type Locale } from "../lib/i18n";

type Modal = "lesson" | "quiz" | "animation" | "system" | null;

/**
 * Renders an organ illustration, or its accent glyph for organs that ship as a
 * 3D model without the painted asset set. Keeps every image slot filled instead
 * of leaving a broken `<img>` behind.
 */
function OrganArt({
  organ,
  asset,
  alt,
  size,
}: {
  organ: Organ;
  asset: "thumb" | "organ" | "microscopic" | "compare" | "location";
  alt: string;
  size?: number;
}) {
  if (!organ.illustrated) {
    // An empty alt means a surrounding control already names this, so the
    // glyph should be skipped rather than announced with no label.
    const labelling = alt ? { role: "img", "aria-label": alt } : { "aria-hidden": true };
    return (
      <span className="art-fallback" style={{ "--art-accent": organ.accent } as React.CSSProperties} {...labelling}>
        {organ.icon}
      </span>
    );
  }
  return (
    <img
      key={`${organ.id}-${asset}`}
      src={`/anatomy/${organ.id}/${asset}.webp`}
      alt={alt}
      width={size}
      height={size}
      loading={asset === "thumb" ? "eager" : "lazy"}
      decoding="async"
    />
  );
}

export function AnatomyApp() {
  const [organId, setOrganId] = useState<OrganId>("heart");
  const [locale, setLocale] = useState<Locale>("en");
  const [autoRotate, setAutoRotate] = useState(true);
  const [compare, setCompare] = useState(false);
  const [modal, setModal] = useState<Modal>(null);
  const [query, setQuery] = useState("");
  const [mobileLibrary, setMobileLibrary] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  const prefetched = useRef(new Set<OrganId>());
  const copy = ui[locale];
  const organ = localizeOrgan(organById[organId], locale);
  const reference = localizeOrgan(organById[organId === "heart" ? "brain" : "heart"], locale);
  const filteredOrgans = useMemo(
    () => organs.filter((item) => {
      const localized = localizeOrgan(item, locale);
      return `${item.name} ${item.system} ${localized.name} ${localized.system}`.toLowerCase().includes(query.toLowerCase());
    }),
    [query, locale],
  );

  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";
    window.localStorage.setItem("anatomy-locale", locale);
  }, [locale]);

  useEffect(() => {
    const saved = window.localStorage.getItem("anatomy-locale");
    if (saved === "ar" || saved === "en") setLocale(saved);
  }, []);

  useEffect(() => {
    if (!contentRef.current) return;
    gsap.fromTo(contentRef.current.querySelectorAll("[data-reveal]"),
      { opacity: 0, y: 8 },
      { opacity: 1, y: 0, duration: 0.48, stagger: 0.035, ease: "power2.out", overwrite: true },
    );
  }, [organId]);

  const selectOrgan = (id: OrganId) => {
    if (organById[id].illustrated) {
      ["organ", "microscopic", "compare", "location"].forEach((asset) => {
        const image = new Image();
        image.src = `/anatomy/${id}/${asset}.webp`;
      });
    }
    setOrganId(id);
    setMobileLibrary(false);
    setCompare(false);
  };

  // Warms the model in the HTTP cache while the pointer is still travelling,
  // so the switch usually renders without a visible loading pass.
  const prefetchOrgan = (id: OrganId) => {
    if (id === organId || prefetched.current.has(id)) return;
    prefetched.current.add(id);
    void fetch(organById[id].model, { priority: "low" } as RequestInit).catch(() => {});
  };

  return (
    <main className={`app-shell locale-${locale}`} dir={locale === "ar" ? "rtl" : "ltr"}>
      <header className="topbar">
        <button className="brand" type="button" onClick={() => selectOrgan("heart")} aria-label={locale === "ar" ? "العودة إلى الصفحة الرئيسية" : "Anatomy Atelier home"}>
          <strong>Anatomy Atelier<sup>✦</sup></strong>
          <em>{copy.brandTagline}</em>
        </button>
        <nav className="main-nav" aria-label={locale === "ar" ? "التنقل الرئيسي" : "Primary navigation"}>
          <button className="active"><Compass size={17} /> {copy.explore}</button>
          <button><BrainCircuit size={17} /> {copy.systems}</button>
          <button onClick={() => setModal("lesson")}><BookOpen size={17} /> {copy.lessons}</button>
          <button onClick={() => setMobileLibrary(true)}><LibraryBig size={17} /> {copy.library}</button>
          <button><NotebookPen size={17} /> {copy.notes}</button>
        </nav>
        <label className="search-box">
          <Search size={17} />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={copy.search} />
        </label>
        <button className="locale-switch" type="button" onClick={() => setLocale(locale === "en" ? "ar" : "en")} aria-label={locale === "ar" ? "Switch to English" : "التبديل إلى العربية"}>{copy.language}</button>
        <button className="profile" aria-label={copy.profile}><span>MA</span><ChevronDown size={15} /></button>
        <button className="mobile-library-trigger" onClick={() => setMobileLibrary(true)} aria-label={copy.openLibrary}><LibraryBig size={20} /></button>
      </header>

      <div className="workspace">
        <aside className={`organ-library ${mobileLibrary ? "open" : ""}`}>
          <div className="panel-heading">
            <span>{copy.organLibrary}</span>
            <button aria-label={copy.closeLibrary} className="mobile-close" onClick={() => setMobileLibrary(false)}><X size={17} /></button>
            <button aria-label={copy.saved}><Bookmark size={17} /></button>
          </div>
          <div className="organ-list">
            {filteredOrgans.map((baseItem) => {
              const item = localizeOrgan(baseItem, locale);
              return (
              <button
                type="button"
                key={baseItem.id}
                className={`organ-item ${organId === item.id ? "active" : ""}`}
                onClick={() => selectOrgan(baseItem.id)}
                onPointerEnter={() => prefetchOrgan(baseItem.id)}
                onFocus={() => prefetchOrgan(baseItem.id)}
                style={{ "--item-accent": item.accent } as React.CSSProperties}
              >
                <span className="organ-glyph">
                  <OrganArt organ={item} asset="thumb" alt={`${item.name} thumbnail`} size={47} />
                </span>
                <span><b>{item.name}</b><small>{item.system}</small></span>
                {organId === item.id && <Heart className="favorite" size={14} fill="currentColor" />}
              </button>
              );
            })}
          </div>
          <button className="view-all" onClick={() => setQuery("")}>{copy.viewAll} <ArrowRight size={14} /></button>
          <blockquote>
            <Sparkles size={18} />
            <p>{copy.curiosity}</p>
            <em>{copy.keepExploring}</em>
          </blockquote>
        </aside>

        <OrganViewer
          organ={organ}
          locale={locale}
          autoRotate={autoRotate}
          onAutoRotate={setAutoRotate}
          compare={compare}
          onCompare={() => setCompare(!compare)}
        />

        <aside className="info-panel" ref={contentRef}>
          <div className="info-kicker" data-reveal><Heart size={13} fill="currentColor" /> {copy.the} {organ.name}</div>
          <div className="info-title-row" data-reveal>
            <div><h1>{organ.name}</h1><em>{organ.poetic}</em></div>
            <span className="specimen-stamp">
              <OrganArt organ={organ} asset="organ" alt={`${organ.name} anatomical illustration`} size={92} />
            </span>
          </div>
          <p className="description" data-reveal>{organ.description}</p>
          <div className="rule" />
          <h2 data-reveal>{copy.keyFacts}</h2>
          <dl className="key-facts">
            <div data-reveal><dt><span>◇</span> {copy.size}</dt><dd>{organ.size}</dd></div>
            <div data-reveal><dt><span>♙</span> {copy.weight}</dt><dd>{organ.weight}</dd></div>
            <div data-reveal><dt><span>⌁</span> {copy.daily}</dt><dd>{organ.dailyFact}</dd></div>
            <div data-reveal><dt><span>⌖</span> {copy.location}</dt><dd>{organ.location}</dd></div>
            <div data-reveal><dt><span>❋</span> {copy.bloodSupply}</dt><dd>{organ.bloodSupply}</dd></div>
            <div data-reveal><dt><span>◈</span> {copy.function}</dt><dd>{organ.function}</dd></div>
          </dl>
          <div className="medical-note" data-reveal><Stethoscope size={16} /><p><b>{copy.medicalImportance}</b>{organ.medical}</p></div>
          <div className="fun-note" data-reveal><Sparkles size={15} /><p><b>{copy.didYouKnow}</b>{organ.funFact}</p></div>
          <button className="lesson-button" data-reveal onClick={() => setModal("lesson")}>{copy.viewLesson} <ArrowRight size={16} /></button>
          <div className="action-grid" data-reveal>
            <button onClick={() => setModal("animation")}><Play size={15} /> {copy.animate}</button>
            <button onClick={() => setModal("quiz")}><CircleHelp size={15} /> {copy.quiz}</button>
            <button onClick={() => setCompare(!compare)} className={compare ? "active" : ""}><Share2 size={15} /> {copy.compare}</button>
          </div>
        </aside>
      </div>

      {compare && (
        <section className="compare-strip" aria-label="Organ comparison">
          <div className="compare-organ"><OrganArt organ={organ} asset="thumb" alt="" /><span>{copy.comparing}</span><strong>{organ.name}</strong><small>{organ.system}</small></div>
          <b>vs.</b>
          <div className="compare-organ"><OrganArt organ={reference} asset="thumb" alt="" /><span>{copy.reference}</span><strong>{reference.name}</strong><small>{reference.system}</small></div>
          <dl><div><dt>{copy.primaryRole}</dt><dd>{organ.function}</dd></div><div><dt>{copy.scale}</dt><dd>{organ.size}</dd></div></dl>
          <button onClick={() => setCompare(false)} aria-label="Close comparison"><X size={16} /></button>
        </section>
      )}

      <section className="learning-cards" aria-label={`${organ.name} learning resources`}>
        <article className="curiosity-card">
          <span>✿</span><p>Learning is<br />an act of curiosity.</p><em>Keep exploring!</em>
        </article>
        <article>
          <header><div><em>{copy.microscopicView}</em><h3>{organ.tissue}</h3></div><Microscope size={17} /></header>
          <div className="microscope-visual organ-card-image"><OrganArt organ={organ} asset="microscopic" alt={`${organ.name} microscopic tissue view`} /></div>
          <button onClick={() => setModal("lesson")}>{copy.exploreTissue} <ArrowRight size={14} /></button>
        </article>
        <article>
          <header><div><em>{copy.compareOrgans}</em><h3>{organ.comparison}</h3></div><Share2 size={17} /></header>
          <div className="comparison-visual organ-card-image"><OrganArt organ={organ} asset="compare" alt={`${organ.comparison} anatomical comparison`} /></div>
          <button onClick={() => setCompare(true)}>{copy.openComparison} <ArrowRight size={14} /></button>
        </article>
        <article>
          <header><div><em>{copy.functionAnimation}</em><h3>{organ.function}</h3></div><Play size={17} /></header>
          {/* The artwork itself is the control, so the play badge inside it is
              decorative rather than a nested button. */}
          <button
            type="button"
            className="function-visual organ-card-image"
            onClick={() => setModal("animation")}
            aria-label={`Play the ${organ.name.toLowerCase()} function animation`}
          >
            <OrganArt organ={organ} asset="organ" alt="" />
            <i className="function-pulse" />
            <span className="play-badge"><Play size={18} fill="currentColor" /></span>
          </button>
          <button onClick={() => setModal("animation")}>{copy.playAnimation} <ArrowRight size={14} /></button>
        </article>
        <article>
          <header><div><em>{copy.clinicalNotes}</em><h3>{copy.commonConditions}</h3></div><FileText size={17} /></header>
          <ul>{organ.conditions.map((condition) => <li key={condition}>{condition}</li>)}</ul>
          <button onClick={() => setModal("lesson")}>{copy.seeAll} <ArrowRight size={14} /></button>
        </article>
        <article className="system-card">
          <header><div><em>{copy.whereItWorks}</em><h3>{organ.system}</h3></div><BrainCircuit size={17} /></header>
          <button
            type="button"
            className="system-visual organ-card-image"
            onClick={() => setModal("system")}
            aria-label={`See where the ${organ.name.toLowerCase()} sits in the body`}
          >
            <OrganArt organ={organ} asset="location" alt="" />
          </button>
          <button onClick={() => setModal("system")}>{copy.seeSystem} <ArrowRight size={14} /></button>
        </article>
      </section>

      {modal && <LearningModal type={modal} organ={organ} locale={locale} onClose={() => setModal(null)} />}
      {mobileLibrary && <button className="drawer-backdrop" aria-label={copy.closeLibrary} onClick={() => setMobileLibrary(false)} />}
      <LearningHub locale={locale} activeOrgan={organId} />

      <footer className="site-footer"><span>{copy.footer}</span><small>© {new Date().getFullYear()} Anatomy Atelier</small></footer>
    </main>
  );
}

const MODAL_ICON: Record<Exclude<Modal, null>, string> = {
  quiz: "?",
  animation: "▶",
  system: "⌖",
  lesson: "✦",
};

function LearningModal({ type, organ, locale, onClose }: { type: Exclude<Modal, null>; organ: Organ; locale: Locale; onClose: () => void }) {
  const copy = ui[locale];
  const organName = organ.name;
  const title = locale === "ar"
    ? type === "quiz" ? `اختبار سريع: ${organName}`
      : type === "animation" ? `${organName} أثناء العمل`
      : type === "system" ? `${organName} داخل الجسم`
      : `داخل ${organName}`
    : type === "quiz" ? `${organName} quick quiz`
    : type === "animation" ? `${organName} in motion`
    // Avoids gluing onto `system`, whose wording varies per organ
    // ("Cardiovascular" vs "Nervous System"), and stays grammatical for the
    // plural organs too.
    : type === "system" ? `${organName} in the body`
    : `Inside the ${organName.toLowerCase()}`;
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        className={`learning-modal ${type === "system" ? "wide" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button className="modal-close" onClick={onClose} aria-label={copy.close}><X size={18} /></button>
        <span className="modal-icon">{MODAL_ICON[type]}</span>
        <em>{copy.guidedDiscovery}</em>
        <h2 id="modal-title">{title}</h2>
        {type === "quiz" ? (
          <div className="quiz-options">
            <p>{copy.quizQuestion}</p>
            <button onClick={onClose}>{copy.quizA}</button>
            <button onClick={onClose}>{copy.quizB}</button>
            <button onClick={onClose}>{copy.quizC}</button>
          </div>
        ) : type === "system" ? (
          <>
            <p>{organ.location}. {copy.systemCopy}</p>
            {/* Shown whole rather than cropped into the circular demo — the
                point of this view is the figure and its vessels. */}
            <figure className="modal-figure">
              <OrganArt organ={organ} asset="location" alt={`${organName} shown in place within the ${organ.system.toLowerCase()}`} />
            </figure>
            <dl className="modal-facts">
              <div><dt>{copy.system}</dt><dd>{organ.system}</dd></div>
              <div><dt>{copy.primaryRole}</dt><dd>{organ.function}</dd></div>
              <div><dt>{copy.bloodSupply}</dt><dd>{organ.bloodSupply}</dd></div>
            </dl>
            <button className="lesson-button" onClick={onClose}>{copy.continueExploring} <ArrowRight size={16} /></button>
          </>
        ) : (
          <>
            <p>{copy.lessonCopy}</p>
            <div className={`modal-demo ${type === "animation" ? "moving" : ""}`}><OrganArt organ={organ} asset="organ" alt={`${organName} illustration`} /></div>
            <button className="lesson-button" onClick={onClose}>{copy.continueExploring} <ArrowRight size={16} /></button>
          </>
        )}
      </section>
    </div>
  );
}
