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
  limit
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

const pendingList = document.getElementById('pending-list');
const verifiedList = document.getElementById('verified-list');
const refreshBtn = document.getElementById('refreshBtn');
const pendingSearch = document.getElementById('pending-search');
const verifiedSearch = document.getElementById('verified-search');
const pendingLoading = document.getElementById('pending-loading');
const verifiedLoading = document.getElementById('verified-loading');

let allPendingUsers = [];
let allVerifiedUsers = [];

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
        await loadData();
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
        await loadData();
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
  const pendingTerm = pendingSearch.value;
  const verifiedTerm = verifiedSearch.value;
  
  pendingList.innerHTML = '';
  verifiedList.innerHTML = '';
  
  const filteredPending = filterUsers(allPendingUsers, pendingTerm);
  const filteredVerified = filterUsers(allVerifiedUsers, verifiedTerm);
  
  filteredPending.forEach(user => {
    pendingList.appendChild(userCard(user, false));
  });
  
  filteredVerified.forEach(user => {
    verifiedList.appendChild(userCard(user, true));
  });
}

async function loadData() {
  pendingLoading.style.display = 'block';
  verifiedLoading.style.display = 'block';
  pendingList.innerHTML = '';
  verifiedList.innerHTML = '';
  
  try {
    // Pending users
    const qPending = query(collection(db, 'users'), where('isVerified', '==', false));
    const snapPending = await getDocs(qPending);
    allPendingUsers = snapPending.docs.map(docSnap => ({ ...docSnap.data(), uid: docSnap.id }));
    
    // Verified users
    const qVerified = query(collection(db, 'users'), where('isVerified', '==', true));
    const snapVerified = await getDocs(qVerified);
    allVerifiedUsers = snapVerified.docs.map(docSnap => ({ ...docSnap.data(), uid: docSnap.id }));
    
    updateDisplayedUsers();
  } catch (error) {
    console.error("Error loading data:", error);
    alert("Failed to load data: " + error.message);
  } finally {
    pendingLoading.style.display = 'none';
    verifiedLoading.style.display = 'none';
  }
}

// Add event listeners
refreshBtn.addEventListener('click', loadData);
pendingSearch.addEventListener('input', updateDisplayedUsers);
verifiedSearch.addEventListener('input', updateDisplayedUsers);

// Initial load
loadData().catch(console.error);
