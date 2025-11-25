// WebSocket connection
let ws = null;
let reconnectTimeout = null;

// DOM elements
const programsGrid = document.getElementById('programsGrid');
const emptyState = document.getElementById('emptyState');
const wsStatus = document.getElementById('wsStatus');
const wsStatusText = document.getElementById('wsStatusText');

// Connect to WebSocket
function connectWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    console.log('WebSocket connected');
    wsStatus.classList.add('connected');
    wsStatus.classList.remove('disconnected');
    wsStatusText.textContent = 'Connected';

    if (reconnectTimeout) {
      clearTimeout(reconnectTimeout);
      reconnectTimeout = null;
    }
  };

  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);

    if (message.type === 'status') {
      updateProgramsDisplay(message.data);
    }
  };

  ws.onerror = (error) => {
    console.error('WebSocket error:', error);
  };

  ws.onclose = () => {
    console.log('WebSocket disconnected');
    wsStatus.classList.remove('connected');
    wsStatus.classList.add('disconnected');
    wsStatusText.textContent = 'Disconnected';

    // Attempt to reconnect after 3 seconds
    reconnectTimeout = setTimeout(connectWebSocket, 3000);
  };
}

// Fetch programs from API
async function fetchPrograms() {
  try {
    const response = await fetch('/api/programs');
    const programs = await response.json();
    updateProgramsDisplay(programs);
  } catch (error) {
    console.error('Error fetching programs:', error);
  }
}

// Update programs display
function updateProgramsDisplay(programs) {
  if (!programs || programs.length === 0) {
    programsGrid.classList.add('hidden');
    emptyState.classList.remove('hidden');
    return;
  }

  programsGrid.classList.remove('hidden');
  emptyState.classList.add('hidden');

  // Update existing cards or create new ones
  programs.forEach(program => {
    let card = document.querySelector(`[data-program-id="${program.id}"]`);

    if (!card) {
      card = createProgramCard(program);
      programsGrid.appendChild(card);
    } else {
      updateProgramCard(card, program);
    }
  });

  // Remove cards for programs that no longer exist
  const existingCards = programsGrid.querySelectorAll('.program-card');
  existingCards.forEach(card => {
    const id = card.getAttribute('data-program-id');
    if (!programs.find(p => p.id === id)) {
      card.remove();
    }
  });
}

// Create program card
function createProgramCard(program) {
  const template = document.getElementById('programCardTemplate');
  const card = template.content.cloneNode(true).querySelector('.program-card');

  card.setAttribute('data-program-id', program.id);

  const btnStart = card.querySelector('.btn-start');
  const btnStop = card.querySelector('.btn-stop');
  const btnRestart = card.querySelector('.btn-restart');
  const btnLogs = card.querySelector('.btn-logs');

  btnStart.addEventListener('click', () => startProgram(program.id));
  btnStop.addEventListener('click', () => stopProgram(program.id));
  btnRestart.addEventListener('click', () => restartProgram(program.id));
  btnLogs.addEventListener('click', () => toggleLogs(program.id, card));

  const btnCloseLogs = card.querySelector('.btn-close-logs');
  btnCloseLogs.addEventListener('click', () => {
    card.querySelector('.program-logs').classList.add('hidden');
  });

  updateProgramCard(card, program);

  return card;
}

// Update program card
function updateProgramCard(card, program) {
  card.querySelector('.program-name').textContent = program.name;
  card.querySelector('.program-path').textContent = program.path;
  card.querySelector('.program-pid').textContent = program.pid || 'N/A';

  const statusBadge = card.querySelector('.program-status');
  statusBadge.textContent = program.status;
  statusBadge.className = `program-status badge ${program.status}`;

  const btnStart = card.querySelector('.btn-start');
  const btnStop = card.querySelector('.btn-stop');
  const btnRestart = card.querySelector('.btn-restart');

  if (program.status === 'running') {
    btnStart.disabled = true;
    btnStop.disabled = false;
    btnRestart.disabled = false;
  } else {
    btnStart.disabled = false;
    btnStop.disabled = true;
    btnRestart.disabled = true;
  }
}

// API functions
async function startProgram(id) {
  try {
    const response = await fetch(`/api/programs/${id}/start`, {
      method: 'POST'
    });
    const result = await response.json();

    if (!result.success) {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    console.error('Error starting program:', error);
    alert('Failed to start program');
  }
}

async function stopProgram(id) {
  try {
    const response = await fetch(`/api/programs/${id}/stop`, {
      method: 'POST'
    });
    const result = await response.json();

    if (!result.success) {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    console.error('Error stopping program:', error);
    alert('Failed to stop program');
  }
}

async function restartProgram(id) {
  try {
    const response = await fetch(`/api/programs/${id}/restart`, {
      method: 'POST'
    });
    const result = await response.json();

    if (!result.success) {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    console.error('Error restarting program:', error);
    alert('Failed to restart program');
  }
}

async function toggleLogs(id, card) {
  const logsContainer = card.querySelector('.program-logs');
  const logsContent = card.querySelector('.logs-content');

  if (!logsContainer.classList.contains('hidden')) {
    logsContainer.classList.add('hidden');
    return;
  }

  try {
    const response = await fetch(`/api/programs/${id}/logs?lines=100`);
    const logs = await response.json();

    if (logs.length === 0) {
      logsContent.textContent = 'No logs available';
    } else {
      logsContent.textContent = logs.map(log => `${log.time} ${log.text}`).join('\n');
      // Scroll to bottom
      logsContent.scrollTop = logsContent.scrollHeight;
    }

    logsContainer.classList.remove('hidden');
  } catch (error) {
    console.error('Error fetching logs:', error);
    logsContent.textContent = 'Error loading logs';
    logsContainer.classList.remove('hidden');
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  fetchPrograms();
  connectWebSocket();
});
