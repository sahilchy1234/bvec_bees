// Admin Panel for verifying users in Firestore
// 1) Fill your Firebase Web config below.
// 2) Serve this folder with any static server or open index.html directly (if CORS allows).

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.1/firebase-app.js";
import {
  getFirestore,
  collection,
  query,
  where,
  getDocs,
  doc,
  updateDoc,
  orderBy,
  limit,
  deleteDoc
} from "https://www.gstatic.com/firebasejs/10.13.1/firebase-firestore.js";

// TODO: Replace with your web app's Firebase configuration
// You can find this in the Firebase Console (Project settings -> Your apps -> Web app)
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

const page = document.body.dataset.page || 'users';

const dom = {
  pendingList: document.getElementById('pending-list'),
  verifiedList: document.getElementById('verified-list'),
  refreshBtn: document.getElementById('refreshBtn'),
  pendingSearch: document.getElementById('pending-search'),
  verifiedSearch: document.getElementById('verified-search'),
  pendingLoading: document.getElementById('pending-loading'),
  verifiedLoading: document.getElementById('verified-loading'),
  postsList: document.getElementById('posts-list'),
  rumorsList: document.getElementById('rumors-list'),
  postsSearch: document.getElementById('posts-search'),
  rumorsSearch: document.getElementById('rumors-search'),
  postsLoading: document.getElementById('posts-loading'),
  rumorsLoading: document.getElementById('rumors-loading'),
};

const state = {
  pendingUsers: [],
  verifiedUsers: [],
  posts: [],
  rumors: [],
};

const isUsersPage = page === 'users';
const isPostsPage = page === 'posts';
const isRumorsPage = page === 'rumors';

function userCard(user, verified) {
  const div = document.createElement('div');
  div.className = 'card';

  const avatar = user.avatarUrl || '';
  const name = user.name || 'Unknown';
  const roll = user.rollNo || '-';
  const branch = user.branch || '-';
  const semester = user.semester || '-';
  const gender = user.gender || '-';
  const email = user.email || '-';
  const idCard = user.idCardUrl || '';

  div.innerHTML = `
    <div class="card-content">
      <div class="card-header">
        ${avatar ? 
          `<img class="card-avatar" src="${avatar}" alt="avatar" />` : 
          `<div class="default-avatar">${name.charAt(0)}</div>`}
        <div>
          <div class="card-title">${name}</div>
          <div class="card-subtitle">Roll: ${roll}</div>
        </div>
        <span class="card-badge ${verified ? 'badge-verified' : 'badge-pending'}">
          ${verified ? 'Verified' : 'Pending'}
        </span>
      </div>

      <div class="card-details">
        <strong>Branch:</strong> <span>${branch}</span>
        <strong>Semester:</strong> <span>${semester}</span>
        <strong>Gender:</strong> <span>${gender}</span>
        <strong>Email:</strong> <span>${email}</span>
        ${idCard ? `<strong>ID Card:</strong> <a href="${idCard}" target="_blank">View</a>` : ''}
      </div>

      <div class="card-actions"></div>
    </div>
  `;

  const actions = div.querySelector('.card-actions');
  if (!verified) {
    const verifyBtn = document.createElement('button');
    verifyBtn.textContent = 'Verify';
    verifyBtn.onclick = async () => {
      if (!confirm(`Are you sure you want to verify ${name}?`)) return;
      verifyBtn.disabled = true;
      try {
        await updateDoc(doc(db, 'users', user.uid), { isVerified: true });
        await loadUsers();
      } catch (e) {
        console.error(e);
        verifyBtn.disabled = false;
        alert('Failed to verify: ' + e);
      }
    };
    actions.appendChild(verifyBtn);
  } else {
    const markPending = document.createElement('button');
    markPending.className = 'secondary';
    markPending.textContent = 'Mark Pending';
    markPending.onclick = async () => {
      if (!confirm(`Are you sure you want to mark ${name} as pending?`)) return;
      markPending.disabled = true;
      try {
        await updateDoc(doc(db, 'users', user.uid), { isVerified: false });
        await loadUsers();
      } catch (e) {
        console.error(e);
        markPending.disabled = false;
        alert('Failed to update: ' + e);
      }
    };
    actions.appendChild(markPending);
  }

  return div;
}

// Filter users based on search term
function filterUsers(users, term) {
  if (!term) return users;
  term = term.toLowerCase();
  return users.filter(user => 
    (user.name && user.name.toLowerCase().includes(term)) ||
    (user.rollNo && user.rollNo.toLowerCase().includes(term)) ||
    (user.email && user.email.toLowerCase().includes(term))
  );
}

// Update displayed users based on search
function updateDisplayedUsers() {
  if (!isUsersPage || !dom.pendingList || !dom.verifiedList) return;
  const pendingTerm = dom.pendingSearch ? dom.pendingSearch.value : '';
  const verifiedTerm = dom.verifiedSearch ? dom.verifiedSearch.value : '';
  dom.pendingList.innerHTML = '';
  dom.verifiedList.innerHTML = '';
  const filteredPending = filterUsers(state.pendingUsers, pendingTerm);
  const filteredVerified = filterUsers(state.verifiedUsers, verifiedTerm);

  filteredPending.forEach(user => {
    dom.pendingList.appendChild(userCard(user, false));
  });

  filteredVerified.forEach(user => {
    dom.verifiedList.appendChild(userCard(user, true));
  });
}

function postCard(post) {
  const div = document.createElement('div');
  div.className = 'card';

  const author = post.authorName || 'Unknown';
  const content = post.content || '';
  const preview = content.length > 160 ? content.slice(0, 160) + '…' : content;
  const hashtags = Array.isArray(post.hashtags) ? post.hashtags : [];
  const likes = post.likes || 0;
  const comments = post.comments || 0;
  const shares = post.shares || 0;

  let timestampText = '';
  const ts = post.timestamp;
  if (ts && typeof ts.toDate === 'function') {
    const d = ts.toDate();
    timestampText = d.toLocaleString();
  }

  div.innerHTML = `
  <div class="card-content">
    <div class="card-header">
      <div class="default-avatar">${author.charAt(0).toUpperCase()}</div>
      <div>
        <div class="card-title">${author}</div>
        <div class="card-subtitle">${timestampText || 'Post'}</div>
      </div>
    </div>

    <div class="card-details" style="margin-bottom: 12px;">
      <strong>Content:</strong>
      <span>${preview || '-'}</span>
      <strong>Stats:</strong>
      <span>👍 ${likes} · 💬 ${comments} · ↗︎ ${shares}</span>
      ${hashtags.length ? `<strong>Hashtags:</strong><span>${hashtags.map(h => '#' + h).join(' ')}</span>` : ''}
      <strong>ID:</strong>
      <span>${post.id}</span>
    </div>

    <div class="card-actions">
      <button class="danger delete-post-btn">Delete post</button>
    </div>
  </div>
`;

  const deleteBtn = div.querySelector('.delete-post-btn');
  deleteBtn.onclick = async () => {
    if (!confirm('Delete this post permanently?')) return;
    deleteBtn.disabled = true;
    try {
      await deleteDoc(doc(db, 'posts', post.id));
      await loadPosts();
    } catch (e) {
      console.error(e);
      deleteBtn.disabled = false;
      alert('Failed to delete post: ' + e);
    }
  };

  return div;
}

function rumorCard(rumor) {
  const div = document.createElement('div');
  div.className = 'card';

  const content = rumor.content || '';
  const preview = content.length > 160 ? content.slice(0, 160) + '…' : content;
  const yesVotes = rumor.yesVotes || 0;
  const noVotes = rumor.noVotes || 0;
  const commentCount = rumor.commentCount || 0;
  const credibilityScore = typeof rumor.credibilityScore === 'number' ? rumor.credibilityScore : 0.5;

  let timestampText = '';
  const ts = rumor.timestamp;
  if (ts && typeof ts.toDate === 'function') {
    const d = ts.toDate();
    timestampText = d.toLocaleString();
  }

  div.innerHTML = `
  <div class="card-content">
    <div class="card-header">
      <div class="default-avatar">R</div>
      <div>
        <div class="card-title">Rumor</div>
        <div class="card-subtitle">${timestampText || 'Rumor'}</div>
      </div>
      <span class="card-badge badge-pending">${(credibilityScore * 100).toFixed(0)}% score</span>
    </div>

    <div class="card-details" style="margin-bottom: 12px;">
      <strong>Content:</strong>
      <span>${preview || '-'}</span>
      <strong>Stats:</strong>
      <span>✅ ${yesVotes} · ❌ ${noVotes} · 💬 ${commentCount}</span>
      <strong>ID:</strong>
      <span>${rumor.id}</span>
    </div>

    <div class="card-actions">
      <button class="danger delete-rumor-btn">Delete rumor</button>
    </div>
  </div>
`;

  const deleteBtn = div.querySelector('.delete-rumor-btn');
  deleteBtn.onclick = async () => {
    if (!confirm('Delete this rumor permanently?')) return;
    deleteBtn.disabled = true;
    try {
      await deleteDoc(doc(db, 'rumors', rumor.id));
      await loadRumors();
    } catch (e) {
      console.error(e);
      deleteBtn.disabled = false;
      alert('Failed to delete rumor: ' + e);
    }
  };

  return div;
}

function filterPosts(posts, term) {
  if (!term) return posts;
  const t = term.toLowerCase();
  return posts.filter(post =>
    (post.authorName && post.authorName.toLowerCase().includes(t)) ||
    (post.content && post.content.toLowerCase().includes(t)) ||
    (Array.isArray(post.hashtags) && post.hashtags.join(' ').toLowerCase().includes(t))
  );
}

function filterRumors(rumors, term) {
  if (!term) return rumors;
  const t = term.toLowerCase();
  return rumors.filter(rumor =>
    (rumor.content && rumor.content.toLowerCase().includes(t)) ||
    (typeof rumor.id === 'string' && rumor.id.toLowerCase().includes(t))
  );
}

function updateDisplayedPosts() {
  if (!isPostsPage || !dom.postsList) return;
  const term = dom.postsSearch ? dom.postsSearch.value : '';
  dom.postsList.innerHTML = '';
  const filtered = filterPosts(state.posts, term);
  filtered.forEach(post => {
    dom.postsList.appendChild(postCard(post));
  });
}

function updateDisplayedRumors() {
  if (!isRumorsPage || !dom.rumorsList) return;
  const term = dom.rumorsSearch ? dom.rumorsSearch.value : '';
  dom.rumorsList.innerHTML = '';
  const filtered = filterRumors(state.rumors, term);
  filtered.forEach(rumor => {
    dom.rumorsList.appendChild(rumorCard(rumor));
  });
}

async function loadPosts() {
  if (!dom.postsLoading || !dom.postsList) return;
  dom.postsLoading.style.display = 'block';
  dom.postsList.innerHTML = '';
  try {
    const qPosts = query(collection(db, 'posts'), orderBy('timestamp', 'desc'), limit(100));
    const snapPosts = await getDocs(qPosts);
    state.posts = snapPosts.docs.map(docSnap => ({ ...docSnap.data(), id: docSnap.id }));
    updateDisplayedPosts();
  } catch (error) {
    console.error('Error loading posts:', error);
    alert('Failed to load posts: ' + error.message);
  } finally {
    dom.postsLoading.style.display = 'none';
  }
}

async function loadRumors() {
  if (!dom.rumorsLoading || !dom.rumorsList) return;
  dom.rumorsLoading.style.display = 'block';
  dom.rumorsList.innerHTML = '';
  try {
    const qRumors = query(collection(db, 'rumors'), orderBy('timestamp', 'desc'), limit(100));
    const snapRumors = await getDocs(qRumors);
    state.rumors = snapRumors.docs.map(docSnap => ({ ...docSnap.data(), id: docSnap.id }));
    updateDisplayedRumors();
  } catch (error) {
    console.error('Error loading rumors:', error);
    alert('Failed to load rumors: ' + error.message);
  } finally {
    dom.rumorsLoading.style.display = 'none';
  }
}

async function loadUsers() {
  if (!dom.pendingLoading || !dom.verifiedLoading) return;
  dom.pendingLoading.style.display = 'block';
  dom.verifiedLoading.style.display = 'block';
  dom.pendingList.innerHTML = '';
  dom.verifiedList.innerHTML = '';
  
  try {
    // Pending users
    const qPending = query(collection(db, 'users'), where('isVerified', '==', false));
    const snapPending = await getDocs(qPending);
    state.pendingUsers = snapPending.docs.map(docSnap => ({ ...docSnap.data(), uid: docSnap.id }));
    
    // Verified users
    const qVerified = query(collection(db, 'users'), where('isVerified', '==', true));
    const snapVerified = await getDocs(qVerified);
    state.verifiedUsers = snapVerified.docs.map(docSnap => ({ ...docSnap.data(), uid: docSnap.id }));
    
    updateDisplayedUsers();
  } catch (error) {
    console.error("Error loading data:", error);
    alert("Failed to load data: " + error.message);
  } finally {
    dom.pendingLoading.style.display = 'none';
    dom.verifiedLoading.style.display = 'none';
  }
}

function setupUsersPage() {
  dom.refreshBtn?.addEventListener('click', () => {
    loadUsers().catch(console.error);
  });
  dom.pendingSearch?.addEventListener('input', updateDisplayedUsers);
  dom.verifiedSearch?.addEventListener('input', updateDisplayedUsers);
  loadUsers().catch(console.error);
}

function setupPostsPage() {
  dom.refreshBtn?.addEventListener('click', () => {
    loadPosts().catch(console.error);
  });
  dom.postsSearch?.addEventListener('input', updateDisplayedPosts);
  loadPosts().catch(console.error);
}

function setupRumorsPage() {
  dom.refreshBtn?.addEventListener('click', () => {
    loadRumors().catch(console.error);
  });
  dom.rumorsSearch?.addEventListener('input', updateDisplayedRumors);
  loadRumors().catch(console.error);
}

if (isUsersPage) {
  setupUsersPage();
} else if (isPostsPage) {
  setupPostsPage();
} else if (isRumorsPage) {
  setupRumorsPage();
}
