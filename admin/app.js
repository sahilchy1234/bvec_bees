import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.1/firebase-app.js";
import {
  getFirestore,
  collection,
  getDocs,
  doc,
  updateDoc,
  deleteDoc,
  Timestamp,
  query,
  where,
  orderBy,
  limit,
  deleteField,
} from "https://www.gstatic.com/firebasejs/10.13.1/firebase-firestore.js";

const firebaseConfig = {
  apiKey: 'AIzaSyB3DOZuESJkTvRCJA-bcfT8QnoMwG5pn_k',
  appId: '1:508194876863:web:8fe747255da2d77d4c850a',
  messagingSenderId: '508194876863',
  projectId: 'edunova-fa954',
  authDomain: 'edunova-fa954.firebaseapp.com',
  storageBucket: 'edunova-fa954.appspot.com',
  measurementId: 'G-TTVWPRMY77',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const page = document.body.dataset.page || 'home';

const dom = {
  refreshBtn: document.getElementById('refreshBtn'),
  stats: {
    totalUsers: document.getElementById('stat-total-users'),
    newUsers: document.getElementById('stat-new-users'),
    pendingUsers: document.getElementById('stat-pending-users'),
    postsToday: document.getElementById('stat-posts-today'),
    rumorsToday: document.getElementById('stat-rumors-today'),
    dailyLog: document.getElementById('daily-log'),
  },
  users: {
    search: document.getElementById('users-search'),
    list: document.getElementById('users-list'),
    loading: document.getElementById('users-loading'),
  },
  verify: {
    search: document.getElementById('verify-search'),
    list: document.getElementById('verify-list'),
    loading: document.getElementById('verify-loading'),
  },
  posts: {
    search: document.getElementById('posts-search'),
    list: document.getElementById('posts-list'),
    loading: document.getElementById('posts-loading'),
  },
  rumors: {
    search: document.getElementById('rumors-search'),
    list: document.getElementById('rumors-list'),
    loading: document.getElementById('rumors-loading'),
  },
};

const state = {
  users: [],
  posts: [],
  rumors: [],
};

const USERS_LIMIT = 500;
const POSTS_LIMIT = 200;
const RUMORS_LIMIT = 200;

function toDate(value) {
  if (!value) return null;
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (typeof value === 'object' && typeof value.seconds === 'number') {
    return new Date(value.seconds * 1000);
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatDate(date) {
  if (!date) return '—';
  return date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

function formatDateTime(date) {
  if (!date) return '—';
  return date.toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function toggleLoading(el, show) {
  if (!el) return;
  el.style.display = show ? 'block' : 'none';
}

async function fetchUsers(limitCount = USERS_LIMIT) {
  const qUsers = query(collection(db, 'users'), limit(limitCount));
  const snapshot = await getDocs(qUsers);
  state.users = snapshot.docs.map((docSnap) => {
    const data = docSnap.data() || {};
    return {
      id: docSnap.id,
      name: data.name || 'Unnamed User',
      rollNo: data.rollNo || '',
      semester: data.semester || '',
      branch: data.branch || '',
      email: data.email || '',
      avatarUrl: data.avatarUrl || '',
      isVerified: Boolean(data.isVerified),
      isBlocked: Boolean(data.isBlocked),
      blockNote: data.blockNote || '',
      suspendedUntil: toDate(data.suspendedUntil),
      suspensionNote: data.suspensionNote || '',
      createdAt: toDate(data.createdAt || data.created_at || data.timestamp),
    };
  });
  return state.users;
}

async function fetchPosts(limitCount = POSTS_LIMIT) {
  try {
    const qPosts = query(collection(db, 'posts'), orderBy('timestamp', 'desc'), limit(limitCount));
    const snapshot = await getDocs(qPosts);
    state.posts = snapshot.docs.map((docSnap) => {
      const data = docSnap.data() || {};
      return {
        id: docSnap.id,
        authorName: data.authorName || 'Unknown',
        content: data.content || '',
        hashtags: Array.isArray(data.hashtags) ? data.hashtags : [],
        timestamp: toDate(data.timestamp),
        likes: data.likes || 0,
        comments: data.comments || 0,
        shares: data.shares || 0,
      };
    });
  } catch (error) {
    console.error('Error fetching posts:', error);
    const fallback = await getDocs(query(collection(db, 'posts'), limit(limitCount)));
    state.posts = fallback.docs.map((docSnap) => {
      const data = docSnap.data() || {};
      return {
        id: docSnap.id,
        authorName: data.authorName || 'Unknown',
        content: data.content || '',
        hashtags: Array.isArray(data.hashtags) ? data.hashtags : [],
        timestamp: toDate(data.timestamp),
        likes: data.likes || 0,
        comments: data.comments || 0,
        shares: data.shares || 0,
      };
    });
  }
  return state.posts;
}

async function fetchRumors(limitCount = RUMORS_LIMIT) {
  try {
    const qRumors = query(collection(db, 'rumors'), orderBy('timestamp', 'desc'), limit(limitCount));
    const snapshot = await getDocs(qRumors);
    state.rumors = snapshot.docs.map((docSnap) => {
      const data = docSnap.data() || {};
      return {
        id: docSnap.id,
        content: data.content || '',
        timestamp: toDate(data.timestamp),
        yesVotes: data.yesVotes || 0,
        noVotes: data.noVotes || 0,
        commentCount: data.commentCount || 0,
      };
    });
  } catch (error) {
    console.error('Error fetching rumors:', error);
    const fallback = await getDocs(query(collection(db, 'rumors'), limit(limitCount)));
    state.rumors = fallback.docs.map((docSnap) => {
      const data = docSnap.data() || {};
      return {
        id: docSnap.id,
        content: data.content || '',
        timestamp: toDate(data.timestamp),
        yesVotes: data.yesVotes || 0,
        noVotes: data.noVotes || 0,
        commentCount: data.commentCount || 0,
      };
    });
  }
  return state.rumors;
}

function renderDailyLog(entries) {
  if (!dom.stats.dailyLog) return;
  if (!entries.length) {
    dom.stats.dailyLog.innerHTML = '<p class="muted">No activity recorded today.</p>';
    return;
  }
  dom.stats.dailyLog.innerHTML = entries
    .map((entry) => `
      <div class="daily-log__row">
        <span>${entry.label}</span>
        <strong>${entry.value}</strong>
      </div>
    `)
    .join('');
}

function updateHomeStats({ totalUsers, newUsers, pendingUsers, postsToday, rumorsToday }) {
  if (dom.stats.totalUsers) dom.stats.totalUsers.textContent = totalUsers.toString();
  if (dom.stats.newUsers) dom.stats.newUsers.textContent = newUsers.toString();
  if (dom.stats.pendingUsers) dom.stats.pendingUsers.textContent = pendingUsers.toString();
  if (dom.stats.postsToday) dom.stats.postsToday.textContent = postsToday.toString();
  if (dom.stats.rumorsToday) dom.stats.rumorsToday.textContent = rumorsToday.toString();
}

function userMatchesSearch(user, term) {
  if (!term) return true;
  const safeTerm = term.toLowerCase();
  return (
    (user.name && user.name.toLowerCase().includes(safeTerm)) ||
    (user.email && user.email.toLowerCase().includes(safeTerm)) ||
    (user.rollNo && user.rollNo.toLowerCase().includes(safeTerm))
  );
}

function buildUserCard(user, mode = 'users') {
  const card = document.createElement('div');
  card.className = 'card';

  const suspendedActive = user.suspendedUntil && user.suspendedUntil > new Date();
  const statusBadges = [];
  if (!user.isVerified) statusBadges.push('<span class="pill pill-warning">Pending Verification</span>');
  if (user.isBlocked) statusBadges.push('<span class="pill pill-danger">Blocked</span>');
  if (suspendedActive) statusBadges.push(`<span class="pill">Suspended until ${formatDate(user.suspendedUntil)}</span>`);

  card.innerHTML = `
    <div class="card-content">
      <div class="card-header">
        ${user.avatarUrl
          ? `<img class="card-avatar" src="${user.avatarUrl}" alt="avatar" />`
          : `<div class="default-avatar">${(user.name || '?').charAt(0).toUpperCase()}</div>`}
        <div>
          <div class="card-title">${user.name}</div>
          <div class="card-subtitle">Roll: ${user.rollNo || '—'}</div>
        </div>
      </div>
      <div class="status-line">${statusBadges.join('')}</div>
      <div class="card-details">
        <strong>Semester:</strong><span>${user.semester || '—'}</span>
        <strong>Branch:</strong><span>${user.branch || '—'}</span>
        <strong>Email:</strong><span>${user.email || '—'}</span>
        <strong>Joined:</strong><span>${formatDate(user.createdAt)}</span>
        ${user.suspensionNote ? `<strong>Suspension note:</strong><span>${user.suspensionNote}</span>` : ''}
        ${user.isBlocked && user.blockNote ? `<strong>Block note:</strong><span>${user.blockNote}</span>` : ''}
      </div>
      <div class="card-actions"></div>
    </div>
  `;

  const actions = card.querySelector('.card-actions');
  if (mode === 'users') {
    const suspendBtn = document.createElement('button');
    suspendBtn.className = 'secondary';
    suspendBtn.textContent = suspendedActive ? 'Update Suspension' : 'Suspend User';
    suspendBtn.onclick = () => handleSuspendUser(user);
    actions.appendChild(suspendBtn);

    const liftBtn = document.createElement('button');
    liftBtn.className = 'secondary';
    liftBtn.textContent = suspendedActive ? 'Lift Suspension' : 'Clear Suspension';
    liftBtn.disabled = !suspendedActive;
    liftBtn.onclick = () => handleLiftSuspension(user);
    actions.appendChild(liftBtn);

    const blockBtn = document.createElement('button');
    blockBtn.className = user.isBlocked ? '' : 'danger';
    blockBtn.textContent = user.isBlocked ? 'Unblock User' : 'Block User';
    blockBtn.onclick = () => handleToggleBlock(user);
    actions.appendChild(blockBtn);
  } else if (mode === 'verification') {
    const approveBtn = document.createElement('button');
    approveBtn.textContent = 'Verify User';
    approveBtn.onclick = () => handleVerifyUser(user);
    actions.appendChild(approveBtn);

    const rejectBtn = document.createElement('button');
    rejectBtn.className = 'danger';
    rejectBtn.textContent = 'Reject & Block';
    rejectBtn.onclick = () => handleRejectUser(user);
    actions.appendChild(rejectBtn);
  }

  return card;
}

function handleSuspendUser(user) {
  const defaultDays = user.suspendedUntil
    ? Math.max(1, Math.ceil((user.suspendedUntil.getTime() - Date.now()) / (1000 * 60 * 60 * 24)))
    : 3;
  const daysInput = prompt('Suspend user for how many days?', String(defaultDays));
  if (daysInput === null) return;
  const days = Number.parseInt(daysInput, 10);
  if (Number.isNaN(days) || days <= 0) {
    alert('Please enter a valid number of days.');
    return;
  }
  const noteInput = prompt(
    'Provide a suspension note (shown to the user).',
    user.suspensionNote || ''
  );
  if (noteInput === null) return;
  const note = noteInput.trim();
  if (!note) {
    alert('Suspension note cannot be empty.');
    return;
  }
  const until = new Date();
  until.setDate(until.getDate() + days);
  updateDoc(doc(db, 'users', user.id), {
    suspendedUntil: Timestamp.fromDate(until),
    suspensionNote: note,
    suspensionSetAt: Timestamp.now(),
  })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to suspend user: ${error.message}`));
}

function handleLiftSuspension(user) {
  updateDoc(doc(db, 'users', user.id), {
    suspendedUntil: deleteField(),
    suspensionNote: deleteField(),
    suspensionSetAt: deleteField(),
  })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to clear suspension: ${error.message}`));
}

function handleToggleBlock(user) {
  if (user.isBlocked) {
    return handleUnblockUser(user);
  }
  return handleBlockUser(user);
}

function handleVerifyUser(user) {
  updateDoc(doc(db, 'users', user.id), { isVerified: true, isBlocked: false })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to verify user: ${error.message}`));
}

function handleRejectUser(user) {
  if (!confirm('Block this user and mark as pending?')) return;
  updateDoc(doc(db, 'users', user.id), {
    isVerified: false,
    isBlocked: true,
    blockNote: 'Rejected during verification',
  })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to reject user: ${error.message}`));
}

function handleBlockUser(user) {
  const noteInput = prompt(
    `Block ${user.name || 'user'}? Enter an internal admin note (not shown to the user).`,
    user.blockNote || ''
  );
  if (noteInput === null) return;
  const note = noteInput.trim();
  if (!note) {
    alert('Block note cannot be empty.');
    return;
  }
  updateDoc(doc(db, 'users', user.id), { isBlocked: true, blockNote: note })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to block user: ${error.message}`));
}

function handleUnblockUser(user) {
  if (!confirm(`Unblock ${user.name || 'user'} and allow them to log in again?`)) return;
  updateDoc(doc(db, 'users', user.id), { isBlocked: false, blockNote: deleteField() })
    .then(refreshCurrentPage)
    .catch((error) => alert(`Failed to unblock user: ${error.message}`));
}

function renderUserLists() {
  if (dom.users.list) {
    const term = dom.users.search ? dom.users.search.value.trim().toLowerCase() : '';
    const filtered = state.users.filter((user) => userMatchesSearch(user, term));
    dom.users.list.innerHTML = '';
    if (!filtered.length) {
      dom.users.list.innerHTML = '<p class="muted">No users found.</p>';
    } else {
      filtered.forEach((user) => dom.users.list.appendChild(buildUserCard(user, 'users')));
    }
  }

  if (dom.verify.list) {
    const term = dom.verify.search ? dom.verify.search.value.trim().toLowerCase() : '';
    const filtered = state.users
      .filter((user) => !user.isVerified)
      .filter((user) => userMatchesSearch(user, term));
    dom.verify.list.innerHTML = '';
    if (!filtered.length) {
      dom.verify.list.innerHTML = '<p class="muted">No pending verifications.</p>';
    } else {
      filtered.forEach((user) => dom.verify.list.appendChild(buildUserCard(user, 'verification')));
    }
  }
}

function buildPostCard(post) {
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = `
    <div class="card-content">
      <div class="card-header">
        <div class="default-avatar">${post.authorName.charAt(0).toUpperCase()}</div>
        <div>
          <div class="card-title">${post.authorName}</div>
          <div class="card-subtitle">${formatDateTime(post.timestamp)}</div>
        </div>
      </div>
      <div class="card-details" style="margin-bottom:12px;">
        <strong>Content:</strong><span>${post.content ? post.content.slice(0, 180) : '—'}</span>
        <strong>Stats:</strong><span>👍 ${post.likes} · 💬 ${post.comments} · ↗︎ ${post.shares}</span>
        ${post.hashtags.length ? `<strong>Hashtags:</strong><span>#${post.hashtags.join(' #')}</span>` : ''}
        <strong>ID:</strong><span>${post.id}</span>
      </div>
      <div class="card-actions">
        <button class="danger">Delete Post</button>
      </div>
    </div>
  `;
  card.querySelector('button').onclick = () => handleDeletePost(post.id);
  return card;
}

function buildRumorCard(rumor) {
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = `
    <div class="card-content">
      <div class="card-header">
        <div class="default-avatar">R</div>
        <div>
          <div class="card-title">Rumor</div>
          <div class="card-subtitle">${formatDateTime(rumor.timestamp)}</div>
        </div>
      </div>
      <div class="card-details" style="margin-bottom:12px;">
        <strong>Content:</strong><span>${rumor.content ? rumor.content.slice(0, 180) : '—'}</span>
        <strong>Stats:</strong><span>✅ ${rumor.yesVotes} · ❌ ${rumor.noVotes} · 💬 ${rumor.commentCount}</span>
        <strong>ID:</strong><span>${rumor.id}</span>
      </div>
      <div class="card-actions">
        <button class="danger">Delete Rumor</button>
      </div>
    </div>
  `;
  card.querySelector('button').onclick = () => handleDeleteRumor(rumor.id);
  return card;
}

function renderPosts() {
  if (!dom.posts.list) return;
  const term = dom.posts.search ? dom.posts.search.value.trim().toLowerCase() : '';
  const filtered = state.posts.filter((post) => {
    if (!term) return true;
    return (
      post.authorName.toLowerCase().includes(term) ||
      post.content.toLowerCase().includes(term) ||
      post.hashtags.join(' ').toLowerCase().includes(term)
    );
  });
  dom.posts.list.innerHTML = '';
  if (!filtered.length) {
    dom.posts.list.innerHTML = '<p class="muted">No posts match your search.</p>';
    return;
  }
  filtered.forEach((post) => dom.posts.list.appendChild(buildPostCard(post)));
}

function renderRumors() {
  if (!dom.rumors.list) return;
  const term = dom.rumors.search ? dom.rumors.search.value.trim().toLowerCase() : '';
  const filtered = state.rumors.filter((rumor) => {
    if (!term) return true;
    return rumor.content.toLowerCase().includes(term) || rumor.id.toLowerCase().includes(term);
  });
  dom.rumors.list.innerHTML = '';
  if (!filtered.length) {
    dom.rumors.list.innerHTML = '<p class="muted">No rumors match your search.</p>';
    return;
  }
  filtered.forEach((rumor) => dom.rumors.list.appendChild(buildRumorCard(rumor)));
}

function handleDeletePost(postId) {
  if (!confirm('Delete this post permanently?')) return;
  deleteDoc(doc(db, 'posts', postId))
    .then(() => fetchPosts().then(renderPosts))
    .catch((error) => alert(`Failed to delete post: ${error.message}`));
}

function handleDeleteRumor(rumorId) {
  if (!confirm('Delete this rumor permanently?')) return;
  deleteDoc(doc(db, 'rumors', rumorId))
    .then(() => fetchRumors().then(renderRumors))
    .catch((error) => alert(`Failed to delete rumor: ${error.message}`));
}

function refreshCurrentPage() {
  switch (page) {
    case 'users':
      return fetchUsers().then(() => renderUserLists());
    case 'verifications':
      return fetchUsers().then(() => renderUserLists());
    case 'posts':
      return fetchPosts().then(renderPosts);
    case 'rumors':
      return fetchRumors().then(renderRumors);
    case 'home':
    default:
      return loadHomePage();
  }
}

async function loadHomePage() {
  toggleLoading(dom.users.loading, true);
  try {
    const [users, posts, rumors] = await Promise.all([
      fetchUsers(),
      fetchPosts(),
      fetchRumors(),
    ]);
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const stats = {
      totalUsers: users.length,
      newUsers: users.filter((u) => u.createdAt && u.createdAt >= startOfDay).length,
      pendingUsers: users.filter((u) => !u.isVerified).length,
      postsToday: posts.filter((p) => p.timestamp && p.timestamp >= startOfDay).length,
      rumorsToday: rumors.filter((r) => r.timestamp && r.timestamp >= startOfDay).length,
    };
    updateHomeStats(stats);
    renderDailyLog([
      { label: 'New users today', value: stats.newUsers },
      { label: 'Pending verifications', value: stats.pendingUsers },
      { label: 'Posts created today', value: stats.postsToday },
      { label: 'Rumors submitted today', value: stats.rumorsToday },
    ]);
  } catch (error) {
    alert(`Failed to load dashboard: ${error.message}`);
  } finally {
    toggleLoading(dom.users.loading, false);
  }
}

function setupUsersPage() {
  toggleLoading(dom.users.loading, true);
  fetchUsers()
    .then(() => {
      renderUserLists();
      dom.users.search?.addEventListener('input', renderUserLists);
      dom.refreshBtn?.addEventListener('click', refreshCurrentPage);
    })
    .catch((error) => alert(`Failed to load users: ${error.message}`))
    .finally(() => toggleLoading(dom.users.loading, false));
}

function setupVerificationsPage() {
  toggleLoading(dom.verify.loading, true);
  fetchUsers()
    .then(() => {
      renderUserLists();
      dom.verify.search?.addEventListener('input', renderUserLists);
      dom.refreshBtn?.addEventListener('click', refreshCurrentPage);
    })
    .catch((error) => alert(`Failed to load verifications: ${error.message}`))
    .finally(() => toggleLoading(dom.verify.loading, false));
}

function setupPostsPage() {
  toggleLoading(dom.posts.loading, true);
  fetchPosts()
    .then(() => {
      renderPosts();
      dom.posts.search?.addEventListener('input', renderPosts);
      dom.refreshBtn?.addEventListener('click', refreshCurrentPage);
    })
    .catch((error) => alert(`Failed to load posts: ${error.message}`))
    .finally(() => toggleLoading(dom.posts.loading, false));
}

function setupRumorsPage() {
  toggleLoading(dom.rumors.loading, true);
  fetchRumors()
    .then(() => {
      renderRumors();
      dom.rumors.search?.addEventListener('input', renderRumors);
      dom.refreshBtn?.addEventListener('click', refreshCurrentPage);
    })
    .catch((error) => alert(`Failed to load rumors: ${error.message}`))
    .finally(() => toggleLoading(dom.rumors.loading, false));
}

function setupHomePage() {
  dom.refreshBtn?.addEventListener('click', refreshCurrentPage);
  loadHomePage();
}

switch (page) {
  case 'users':
    setupUsersPage();
    break;
  case 'verifications':
    setupVerificationsPage();
    break;
  case 'posts':
    setupPostsPage();
    break;
  case 'rumors':
    setupRumorsPage();
    break;
  case 'home':
  default:
    setupHomePage();
    break;
}
