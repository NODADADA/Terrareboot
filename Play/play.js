/*
 * 게임 특징 데이터 — '게임 특징' 메뉴는 이 목록을 읽어서 자동으로 만들어집니다. (세계관 world.js 와 같은 방식)
 *
 * - label : 하단 목차에 보이는 짧은 이름
 * - kicker: 제목 위 작은 글씨
 * - title / titleEn : 제목 / 영문 제목 (한 줄에 들어가는 짧은 이름)
 * - headline: 제목 아래 한 줄 문구 (긴 홍보 문구는 여기에)
 * - accent: 이 슬라이드를 보는 동안의 강조색 (상단 메뉴 밑줄, 라벨, 칩 빛 등)
 * - desc  : 문단 하나당 문자열 하나
 * - visual: 오른쪽 연출 종류 — 'positions' | 'chain' | 'command' | 'map' (모양은 index.html 에서 만듦)
 * - list  : 설명 아래 작은 목록 [이름, 설명] (없으면 생략)
 * - steps : 설명 아래 단계 표시 (없으면 생략)
 * - demo  : 체험판 경로. Unity WebGL 빌드 폴더의 index.html 을 넣으면 '직접 해보기' 버튼이 생김. '' 이면 버튼 없음
 */

// 포지션 설명 ('positions' 연출용, 지금은 목록에서 뺀 상태) — 캐릭터 목록(characters.js)의 role 과 이름이 같아야 해당 캐릭터 얼굴이 자동으로 붙음
window.POSITIONS = [
  { name: '스트라이커', nameEn: 'Striker',
    desc: '공명했을 때 위력이 크게 뛰어오르는 공격수. 방어를 꿰뚫고, 피해를 주변으로 퍼뜨리고, 마무리 일격으로 다음 행동을 이어 간다.' },
  { name: '택티션', nameEn: 'Tactician',
    desc: '판을 짜는 운영가. 행동력을 되돌려 턴을 늘리고, 필요 없는 칩을 순환시키고, 자신의 태그를 옆 칩에 덮어씌워 공명을 만들어 낸다.' },
  { name: '가디언', nameEn: 'Guardian',
    desc: '아군을 지키는 방벽. 적의 공격을 자신에게 끌어오고, 공명하면 아군 전체에 보호막을 펼치며, 치명적인 상태 이상을 걷어 낸다.' },
];

// 하단 목차 맨 앞에 붙는 묶음 이름 — 게임 장르를 함께 보여 줌
window.PLAY_GROUP = 'PLAY';

// 게임 특징: [한 줄 제목] + 설명 + 오른쪽 연출 하나 (문구 원본: Play/play.txt)
window.PLAY = [
  {
    label: '태그공명',
    kicker: 'FEATURE 01',
    title: '태그공명', titleEn: 'Tag Resonance',
    headline: '메모리 칩의 태그를 공명시켜라',
    accent: '#5FD3E6',
    visual: 'chain',
    demo: '',
    desc: [
      '지휘관의 전술 단말기 위에서, 배리어 코어와 이레이안의 전투 능력은 모두 같은 규격의 ‘메모리 칩’으로 펼쳐진다. 칩마다 새겨진 고유 태그가 전략의 축이 된다.',
      '손에 쥔 칩 중 이웃한 칩의 태그가 같으면 데이터 링크가 빛나며 공명한다. 공명한 칩을 합칠수록 랭크가 오르고, 위력과 연출도 함께 강해진다.',
    ],
    steps: ['1 RANK', '2 RANK', '3 RANK'],
  },
  {
    label: '지휘관 스킬',
    kicker: 'FEATURE 02',
    title: '지휘관 스킬', titleEn: 'Commander Skill',
    headline: '지휘관이 되어 전황을 뒤집어라',
    accent: '#7FB8FF',
    visual: 'command',
    desc: [
      '체인을 성공시키거나 적을 쓰러뜨릴 때마다 CP(지휘력) 게이지가 차오른다.',
      '모은 CP로 칩에 원하는 태그를 새기거나, 기울어진 전황을 단숨에 뒤집어라.',
    ],
  },
  {
    label: '노드 점령',
    kicker: 'FEATURE 03',
    title: '노드 점령', titleEn: 'Node Capture',
    headline: '나아가며 되찾아라',
    accent: '#6FD6B0',
    visual: 'map',
    desc: [
      '안전지대 네오 에덴에서 이레이안의 본거지 테라 노바까지, 더스트에 잠식된 땅을 거점 하나씩 되찾는다.',
      '붉게 물든 작전 지도가 푸르게 바뀔 때마다, 감춰져 있던 이야기도 한 걸음씩 드러난다.',
    ],
  },
];
