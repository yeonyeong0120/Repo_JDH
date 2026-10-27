/**
 * PLOGGO Promotional Landing Page Interactive Script
 * - Sticky header & active section tracking
 * - Feature 01: Interactive AI Route Recommendation Simulator (Presets + '코스 변경' Safe Swap)
 * - Feature 02: Interactive YOLOv8 Vision Viewfinder & '이렇게 담을까요?' Confirm Sheet Stepper
 * - Section 03: 4-Step App Screen Walkthrough Tabs
 */

document.addEventListener('DOMContentLoaded', () => {
  /* ========================================================================
     1. Sticky Header & Mobile Navigation
     ======================================================================== */
  const siteHeader = document.getElementById('siteHeader');
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const navLinks = document.getElementById('navLinks');
  const navAnchors = navLinks ? navLinks.querySelectorAll('a') : [];

  window.addEventListener('scroll', () => {
    if (window.scrollY > 20) {
      siteHeader.classList.add('scrolled');
    } else {
      siteHeader.classList.remove('scrolled');
    }
  });

  if (mobileMenuBtn && navLinks) {
    mobileMenuBtn.addEventListener('click', () => {
      navLinks.classList.toggle('open');
    });

    navAnchors.forEach((a) => {
      a.addEventListener('click', () => {
        navLinks.classList.remove('open');
      });
    });
  }

  /* ========================================================================
     2. Feature 01: AI Route Recommendation Simulator
     ======================================================================== */
  const routePresets = {
    bupyeong: {
      searchAddress: '인천 부평구 부평공원 분수광장',
      destName: '부평공원 분수광장',
      variants: [
        {
          eta: '2.4km · 38분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 145 310 175 255 T 285 225 T 355 170 L 405 115',
          h1: { left: '35%', top: '58%' },
          h2: { left: '57%', top: '51%' },
          h3: { left: '71%', top: '39%' },
          dest: { left: '81%', top: '26%' }
        },
        {
          eta: '2.7km · 42분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 120 220 165 205 T 265 250 T 360 195 L 405 115',
          h1: { left: '33%', top: '46%' },
          h2: { left: '53%', top: '56%' },
          h3: { left: '72%', top: '44%' },
          dest: { left: '81%', top: '26%' }
        }
      ]
    },
    gulpo: {
      searchAddress: '인천 부평구 굴포천 생태하천 산책로',
      destName: '굴포천 생태하천 산책로',
      variants: [
        {
          eta: '3.1km · 48분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 155 335 215 280 T 315 210 T 390 155 L 420 120',
          h1: { left: '43%', top: '63%' },
          h2: { left: '63%', top: '48%' },
          h3: { left: '78%', top: '35%' },
          dest: { left: '84%', top: '27%' }
        },
        {
          eta: '2.9km · 45분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 130 250 195 235 T 295 190 T 370 150 L 420 120',
          h1: { left: '39%', top: '53%' },
          h2: { left: '59%', top: '43%' },
          h3: { left: '74%', top: '34%' },
          dest: { left: '84%', top: '27%' }
        }
      ]
    },
    mangwon: {
      searchAddress: '서울 마포구 망원한강공원 초록길',
      destName: '망원한강공원 초록길',
      variants: [
        {
          eta: '1.9km · 29분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 160 275 205 245 T 290 215 T 350 160 L 395 125',
          h1: { left: '41%', top: '55%' },
          h2: { left: '58%', top: '49%' },
          h3: { left: '70%', top: '36%' },
          dest: { left: '79%', top: '28%' }
        },
        {
          eta: '2.2km · 34분',
          hotspots: '정화지역 3곳',
          factories: '공장지대 0곳',
          path: 'M 85 300 Q 140 330 220 295 T 310 230 T 365 175 L 395 125',
          h1: { left: '44%', top: '67%' },
          h2: { left: '62%', top: '52%' },
          h3: { left: '73%', top: '40%' },
          dest: { left: '79%', top: '28%' }
        }
      ]
    }
  };

  let currentRouteKey = 'bupyeong';
  let currentVariantIdx = 0;

  const presetButtons = document.querySelectorAll('.route-preset-tab');
  const mapSearchText = document.getElementById('mapSearchText');
  const sheetDestName = document.getElementById('sheetDestName');
  const mapEtaBubble = document.getElementById('mapEtaBubble');
  const metaHotspotCount = document.getElementById('metaHotspotCount');
  const metaFactoryCount = document.getElementById('metaFactoryCount');
  const routePathSvg = document.getElementById('routePathSvg');
  const pinHotspot1 = document.getElementById('pinHotspot1');
  const pinHotspot2 = document.getElementById('pinHotspot2');
  const pinHotspot3 = document.getElementById('pinHotspot3');
  const pinDest = document.getElementById('pinDest');
  const btnCourseChange = document.getElementById('btnCourseChange');

  function applyRouteState(routeKey, variantIdx) {
    const preset = routePresets[routeKey];
    if (!preset) return;
    const v = preset.variants[variantIdx % preset.variants.length];

    if (mapSearchText) mapSearchText.textContent = preset.searchAddress;
    if (sheetDestName) sheetDestName.textContent = preset.destName;
    if (mapEtaBubble) mapEtaBubble.textContent = v.eta;
    if (metaHotspotCount) metaHotspotCount.textContent = v.hotspots;
    if (metaFactoryCount) metaFactoryCount.textContent = v.factories;

    if (routePathSvg) {
      routePathSvg.setAttribute('d', v.path);
      routePathSvg.classList.remove('animating');
      void routePathSvg.offsetWidth; // trigger reflow
      routePathSvg.classList.add('animating');
    }

    if (pinHotspot1) {
      pinHotspot1.style.left = v.h1.left;
      pinHotspot1.style.top = v.h1.top;
    }
    if (pinHotspot2) {
      pinHotspot2.style.left = v.h2.left;
      pinHotspot2.style.top = v.h2.top;
    }
    if (pinHotspot3) {
      pinHotspot3.style.left = v.h3.left;
      pinHotspot3.style.top = v.h3.top;
    }
    if (pinDest) {
      pinDest.style.left = v.dest.left;
      pinDest.style.top = v.dest.top;
    }
  }

  presetButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      presetButtons.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      currentRouteKey = btn.getAttribute('data-route') || 'bupyeong';
      currentVariantIdx = 0;
      applyRouteState(currentRouteKey, currentVariantIdx);
    });
  });

  if (btnCourseChange) {
    btnCourseChange.addEventListener('click', () => {
      btnCourseChange.classList.add('spinning');
      setTimeout(() => {
        currentVariantIdx = (currentVariantIdx + 1) % 2;
        applyRouteState(currentRouteKey, currentVariantIdx);
        btnCourseChange.classList.remove('spinning');
      }, 360);
    });
  }

  /* ========================================================================
     3. Feature 02: YOLOv8 Vision AI Simulator & Confirm Sheet
     ======================================================================== */
  const btnModeLive = document.getElementById('btnModeLive');
  const btnModeSheet = document.getElementById('btnModeSheet');
  const btnCameraShutter = document.getElementById('btnCameraShutter');
  const btnSheetClose = document.getElementById('btnSheetClose');
  const btnSheetConfirm = document.getElementById('btnSheetConfirm');
  const cameraConfirmSheet = document.getElementById('cameraConfirmSheet');

  function setCameraSheetOpen(open) {
    if (!cameraConfirmSheet) return;
    if (open) {
      cameraConfirmSheet.classList.add('open');
      btnModeSheet?.classList.add('active');
      btnModeLive?.classList.remove('active');
    } else {
      cameraConfirmSheet.classList.remove('open');
      btnModeLive?.classList.add('active');
      btnModeSheet?.classList.remove('active');
    }
  }

  btnModeLive?.addEventListener('click', () => setCameraSheetOpen(false));
  btnModeSheet?.addEventListener('click', () => setCameraSheetOpen(true));
  btnCameraShutter?.addEventListener('click', () => setCameraSheetOpen(true));
  btnSheetClose?.addEventListener('click', () => setCameraSheetOpen(false));
  btnSheetConfirm?.addEventListener('click', () => setCameraSheetOpen(false));

  // Stepper buttons inside Confirm Sheet
  const confirmRows = document.querySelectorAll('.confirm-item-row');
  function updateConfirmSheetTotal() {
    let sum = 0;
    confirmRows.forEach((row) => {
      const strong = row.querySelector('.confirm-stepper strong');
      if (strong) {
        sum += parseInt(strong.textContent || '0', 10);
      }
    });
    if (btnSheetConfirm) {
      btnSheetConfirm.textContent = `${sum}개 담기 (+${sum * 20}P)`;
    }
  }

  confirmRows.forEach((row) => {
    const btns = row.querySelectorAll('.stepper-btn');
    const strong = row.querySelector('.confirm-stepper strong');
    const status = row.querySelector('.confirm-item-status');
    if (btns.length === 2 && strong) {
      btns[0].addEventListener('click', () => {
        const cur = parseInt(strong.textContent || '1', 10);
        if (cur > 1) {
          strong.textContent = String(cur - 1);
          if (status) status.textContent = '직접 고쳤어요';
          updateConfirmSheetTotal();
        }
      });
      btns[1].addEventListener('click', () => {
        const cur = parseInt(strong.textContent || '1', 10);
        strong.textContent = String(cur + 1);
        if (status) status.textContent = '직접 고쳤어요';
        updateConfirmSheetTotal();
      });
    }
  });

  // 5 Waste Category Cards Highlight Interaction
  const wasteCards = document.querySelectorAll('.waste-cat-card');
  const yoloBboxes = document.querySelectorAll('.yolo-bbox');

  wasteCards.forEach((card) => {
    card.addEventListener('click', () => {
      const target = card.getAttribute('data-target');
      wasteCards.forEach((c) => c.classList.remove('active'));
      card.classList.add('active');

      // Ensure live viewfinder is visible when clicking category cards
      setCameraSheetOpen(false);

      yoloBboxes.forEach((box) => {
        if (box.getAttribute('data-cat') === target) {
          box.classList.add('highlighted');
        } else {
          box.classList.remove('highlighted');
        }
      });
    });
  });

  yoloBboxes.forEach((box) => {
    box.addEventListener('click', () => {
      const cat = box.getAttribute('data-cat');
      yoloBboxes.forEach((b) => b.classList.toggle('highlighted', b === box));
      wasteCards.forEach((c) => {
        c.classList.toggle('active', c.getAttribute('data-target') === cat);
      });
    });
  });

  /* ========================================================================
     4. Section 03: 4-Step App Screen Walkthrough Tabs
     ======================================================================== */
  const wtTabBtns = document.querySelectorAll('.wt-tab-btn');
  const wtPanels = document.querySelectorAll('.wt-panel');
  const wtVisuals = [
    document.getElementById('wtVisual0'),
    document.getElementById('wtVisual1'),
    document.getElementById('wtVisual2'),
    document.getElementById('wtVisual3')
  ];

  wtTabBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const stepIdx = parseInt(btn.getAttribute('data-step') || '0', 10);

      wtTabBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');

      wtPanels.forEach((panel) => {
        const pIdx = parseInt(panel.getAttribute('data-panel') || '0', 10);
        panel.classList.toggle('active', pIdx === stepIdx);
      });

      wtVisuals.forEach((vis, idx) => {
        if (vis) {
          vis.style.display = idx === stepIdx ? 'block' : 'none';
        }
      });
    });
  });
});
