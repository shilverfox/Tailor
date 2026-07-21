const fs = require('fs');
const path = require('path');

const root = __dirname;
const photoDir = path.join(root, 'source-assets');
const photos = {
  landscape: path.join(photoDir, 'qa-dog-field.png'),
  portrait: path.join(photoDir, 'qa-dog-window.png'),
};
const dataUri = file => `data:image/png;base64,${fs.readFileSync(file).toString('base64')}`;
const photoData = { landscape: dataUri(photos.landscape), portrait: dataUri(photos.portrait) };

const pages = [
  { name: 'cover', title: 'Milo', subtitle: 'A life in moments', image: 'landscape', mode: 'fill' },
  { name: 'dedication', title: 'For Milo', subtitle: 'Made privately from the photographs you chose.' },
  { name: 'contents', title: 'Contents', subtitle: '2019-2021', contents: true },
  { name: 'chapterOpener', title: 'Days together', subtitle: '2019-2021 · A season together', image: 'landscape', mode: 'fill' },
  { name: 'photoSelection', title: 'Days together', subtitle: 'Selected moments from 2019-2021.', diptych: true },
  { name: 'milestone', title: 'A year we remember', subtitle: 'A quiet marker from 2017.', image: 'landscape', mode: 'fill' },
  { name: 'closing', title: 'Kept with care.', subtitle: 'Tailor never changes your original photos.' },
];

const papers = {
  letter: { width: 612, height: 792, paper: { x: 18, y: 18, w: 576, h: 756 } },
  a4: { width: 595, height: 842, paper: { x: 17.5, y: 17.5, w: 560, h: 807 } },
};

const esc = value => value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const rect = (paper, x, y, w, h) => ({ x: paper.x + x * paper.w, y: paper.y + y * paper.h, w: w * paper.w, h: h * paper.h });
const n = value => Number(value.toFixed(2));

function imageLayer(id, href, frame, mode) {
  const fit = mode === 'fit';
  return `<g id="${id}">
    <rect x="${n(frame.x)}" y="${n(frame.y)}" width="${n(frame.w)}" height="${n(frame.h)}" rx="2" fill="#E9E1D2"/>
    <image href="${href}" x="${n(frame.x)}" y="${n(frame.y)}" width="${n(frame.w)}" height="${n(frame.h)}" preserveAspectRatio="xMidYMid ${fit ? 'meet' : 'slice'}"/>
  </g>`;
}

function svgFor(spec, page) {
  const { width, height, paper } = spec;
  const title = rect(paper, .08, .08, .84, .10);
  const subtitle = rect(paper, .08, .17, .84, .06);
  const single = rect(paper, .08, .27, .84, .40);
  const left = rect(paper, .08, .3546875, .41, .230625);
  const right = rect(paper, .6025, .27, .225, .40);
  const titleSize = n(paper.w * .045);
  const bodySize = n(paper.w * .026);
  const titleY = n(title.y + titleSize * .96);
  const subtitleY = n(subtitle.y + bodySize * .98);
  const decorationY = n(paper.y + paper.h * .735);

  let images = '';
  if (page.diptych) {
    images = imageLayer('photo-1-fit-rotation-0', photoData.landscape, left, 'fit') + imageLayer('photo-2-fit-rotation-0', photoData.portrait, right, 'fit');
  } else if (page.image) {
    images = imageLayer(`photo-fill-rotation-0`, photoData[page.image], single, 'fill');
  }

  const contents = page.contents ? `<g id="contents-entry" fill="#183A31">
    <text x="${n(title.x)}" y="${n(paper.y + paper.h * .315)}" font-family="Helvetica, Arial, sans-serif" font-size="${bodySize}">2019-2021</text>
    <line x1="${n(title.x)}" y1="${n(paper.y + paper.h * .34)}" x2="${n(title.x + title.w)}" y2="${n(paper.y + paper.h * .34)}" stroke="#B85639" stroke-width="1.5"/>
  </g>` : '';

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <title>APPROVED · Warm Paper · ${page.name}</title>
  <desc>Production-default geometry. Images are non-user QA assets. Warm Paper automatic rotation 0 degrees.</desc>
  <defs>
    <filter id="paper-grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.72" numOctaves="3" seed="17" result="noise"/>
      <feColorMatrix in="noise" type="saturate" values="0" result="gray"/>
      <feComponentTransfer in="gray"><feFuncA type="table" tableValues="0 0.34"/></feComponentTransfer>
    </filter>
    <clipPath id="paper-clip"><rect x="${paper.x}" y="${paper.y}" width="${paper.w}" height="${paper.h}"/></clipPath>
  </defs>
  <rect id="backdrop" width="${width}" height="${height}" fill="#EFE4D1"/>
  <rect id="paper" x="${paper.x}" y="${paper.y}" width="${paper.w}" height="${paper.h}" fill="#F8F3E8"/>
  <rect id="warm-paper-texture-opacity-034" x="${paper.x}" y="${paper.y}" width="${paper.w}" height="${paper.h}" fill="#8D7D68" filter="url(#paper-grain)" clip-path="url(#paper-clip)" opacity="0.18"/>
  <g id="automatic-content">
    ${images}
    ${contents}
    <line id="clay-accent" x1="${n(title.x)}" y1="${decorationY}" x2="${n(title.x + paper.w * .07)}" y2="${decorationY}" stroke="#B85639" stroke-width="2"/>
    <text id="subtitle" x="${n(subtitle.x)}" y="${subtitleY}" fill="#64756C" font-family="Helvetica, Arial, sans-serif" font-size="${bodySize}">${esc(page.subtitle)}</text>
    <text id="title" x="${n(title.x)}" y="${titleY}" fill="#183A31" font-family="Iowan Old Style, IowanOldStyle-Roman, Georgia, serif" font-size="${titleSize}">${esc(page.title)}</text>
  </g>
</svg>`;
}

for (const [paperName, spec] of Object.entries(papers)) {
  const out = path.join(root, paperName);
  fs.mkdirSync(out, { recursive: true });
  for (const page of pages) fs.writeFileSync(path.join(out, `${page.name}.svg`), svgFor(spec, page));
}
