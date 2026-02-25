const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'RideGo';
const app = document.getElementById('app');
const list = document.getElementById('requestsList');
const acceptId = document.getElementById('acceptId');

const post = async (action, data = {}) => {
  await fetch(`https://${resourceName}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  });
};

const renderRequests = (requests = []) => {
  list.innerHTML = '';
  if (!requests.length) {
    list.innerHTML = '<li>Nenhuma corrida aberta no momento.</li>';
    return;
  }

  requests.forEach((r) => {
    const li = document.createElement('li');
    const tipo = r.type === 'npc' ? 'NPC' : 'Player';
    li.textContent = `#${r.id} | ${tipo} | ${r.passengerName || 'N/A'} | $${r.price}`;
    list.appendChild(li);
  });
};

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'ridego:open') {
    app.classList.remove('hidden');
    renderRequests(data.requests || []);
  }

  if (data.action === 'ridego:close') {
    app.classList.add('hidden');
  }

  if (data.action === 'ridego:updateRequests') {
    renderRequests(data.requests || []);
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('closeUi'));

for (const btn of document.querySelectorAll('[data-action]')) {
  btn.addEventListener('click', async () => {
    const action = btn.dataset.action;
    if (action === 'acceptRide') {
      const id = Number(acceptId.value || 0);
      await post('acceptRide', { requestId: id });
      return;
    }
    await post(action);
  });
}

document.addEventListener('keyup', (e) => {
  if (e.key === 'Escape') post('closeUi');
});
