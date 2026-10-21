/*
 * 게임 특징 데이터 — '게임 특징' 메뉴는 이 목록을 읽어서 자동으로 만들어집니다. (세계관 world.js 와 같은 방식)
 *
 * - label : 하단 목차에 보이는 짧은 이름
 * - kicker: 제목 위 작은 글씨
 * - title / titleEn : 제목 / 영문 제목
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
window.PLAY_GROUP = '턴제 RPG';

// 게임 특징: [한 줄 제목] + 두 문장 + 오른쪽 연출 하나. 규칙 설명보다 '이야기와 어떻게 이어지는지'를 중심으로
window.PLAY = [
  {
    label: '메모리 칩',
    kicker: 'FEATURE 01',
    title: '기억이 무기가 된다', titleEn: 'Memory Chip',
    accent: '#5FD3E6',
    visual: 'chain',
    demo: '',
    desc: [
      '코어에 각인된 기억은 전투에서 ‘메모리 칩’으로 깨어난다.',
      '같은 기억을 품은 칩이 나란히 이어지면 공명이 일어나고, 세 개가 하나로 이어지는 순간 결정타가 터진다.',
    ],
  },
  {
    label: '지휘관',
    kicker: 'FEATURE 02',
    title: '무력한 인간, 지휘관', titleEn: 'Commander',
    accent: '#7FB8FF',
    visual: 'command',
    desc: [
      '플레이어는 아무 능력 없이 살아남은 인간, 지휘관이 되어 코어들을 이끈다.',
      '패가 꼬인 순간 직접 전장에 개입해 칩의 태그를 바꾸고, 끊어진 공명을 다시 잇는다.',
    ],
  },
  {
    label: '수복 작전',
    kicker: 'FEATURE 03',
    title: '되찾는 만큼 나아간다', titleEn: 'Restoration',
    accent: '#6FD6B0',
    visual: 'map',
    desc: [
      '안전지대 네오 에덴에서 이레이안의 본거지 테라 노바까지, 더스트에 잠식된 땅을 거점 하나씩 되찾는다.',
      '붉게 물든 작전 지도가 푸르게 바뀔 때마다, 감춰져 있던 이야기도 한 걸음씩 드러난다.',
    ],
  },
];
