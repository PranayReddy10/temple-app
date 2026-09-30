// Darshan Saathi mark (concept A, "Gopuram & Diya"): the temple tower with a
// lamp's flame over its finial and a lit doorway. Drawn in a 100×100 box.
// fg: the tower; ac: the flame and the doorway.
exports.mark = (fg, ac, { door = true } = {}) => `
  <path d="M50 12c5 6 7 10 7 14a7 7 0 0 1-14 0c0-4 2-8 7-14z" fill="${ac}"/>
  <ellipse cx="50" cy="35" rx="4.5" ry="3" fill="${fg}"/>
  <path d="M42 40h16l2 7H40z" fill="${fg}"/>
  <path d="M37 48h26l2.5 8h-31z" fill="${fg}"/>
  <path d="M32 57h36l3 9H29z" fill="${fg}"/>
  <path d="M26 67h48l3 10H23z" fill="${fg}"/>
  <path d="M20 78h60v10H20z" fill="${fg}"/>
  ${door ? `<path d="M44 88v-9a6 6 0 0 1 12 0v9z" fill="${ac}"/>` : ''}`;

exports.C = { saffron: '#E07A1F', kumkum: '#9B1B30', gold: '#C9A227', goldLight: '#F2C94C', sandal: '#F5EBDC', deep: '#3E2723', ivory: '#FFFDF9' };

// The brand gradient, saffron to kumkum, top-left to bottom-right.
exports.gradient = (id) => `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E07A1F"/><stop offset="1" stop-color="#9B1B30"/></linearGradient></defs>`;
