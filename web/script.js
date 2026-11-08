'use strict';

// ==============================================================================
// ICONS (inline SVG, không cần thư viện ngoài)
// ==============================================================================
const ICONS = {
    bank: '<path d="M3 10l9-6 9 6"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8"/><path d="M3 21h18"/>',
    swap: '<path d="M4 8h14l-3-3M20 16H6l3 3"/>',
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9L17 7M7 17l-2.1 2.1"/>',
    logout: '<path d="M9 4H5v16h4M16 8l4 4-4 4M20 12H9"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>',
    card: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/>',
    wallet: '<path d="M3 7h16a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><path d="M3 7l12-3v3M17 14h2"/>',
    coins: '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    bolt: '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
    down: '<path d="M12 4v14M6 12l6 6 6-6"/>',
    up: '<path d="M12 20V6M6 12l6-6 6 6"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 018 0v4"/>',
    bell: '<path d="M6 16v-5a6 6 0 0112 0v5l2 2H4z"/><path d="M10 21h4"/>',
    monitor: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 21h8M12 16v5"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M8.5 12l2.5 2.5L16 9.5"/>',
    right: '<path d="M9 5l7 7-7 7"/>',
    left: '<path d="M15 5l-7 7 7 7"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
};

function icon(name) {
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ''}</svg>`;
}

function hydrateIcons(root) {
    (root || document).querySelectorAll('[data-i]').forEach(el => { el.innerHTML = icon(el.dataset.i); });
}

// ==============================================================================
// HELPERS
// ==============================================================================
const $ = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));

function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => null);
}

const money = v => '$' + (Number(v) || 0).toLocaleString('en-US');

function esc(v) {
    return String(v === undefined || v === null ? '' : v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}

function fmtDate(ts) {
    const d = new Date(Number(ts) * 1000);
    if (isNaN(d.getTime())) return '--';
    const p = n => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

// ==============================================================================
// STATE
// ==============================================================================
const PER_PAGE = 6;
const S = { data: null, view: 'overview', page: 1, days: 7 };

function txMeta(tr, cid) {
    const sender = tr.sender_name || '---';
    const receiver = tr.receiver_name || '---';

    if (tr.type === 'deposit') {
        return { dir: 'in', label: 'Nạp tiền', who: 'Ngân hàng', note: 'Tiền mặt vào TK', icon: 'down' };
    }
    if (tr.type === 'withdraw') {
        return { dir: 'out', label: 'Rút tiền', who: 'Ngân hàng', note: 'Rút tiền mặt', icon: 'up' };
    }
    if (String(tr.receiver_identifier) === String(cid)) {
        return { dir: 'in', label: 'Nhận tiền', who: sender, note: 'Nhận từ ' + sender, icon: 'down' };
    }
    if (String(tr.receiver_identifier) === 'bank') {
        return { dir: 'out', label: 'Thanh toán', who: receiver, note: receiver, icon: 'card' };
    }
    return { dir: 'out', label: 'Chuyển khoản', who: receiver, note: 'TK đến ' + receiver, icon: 'up' };
}

function amountCell(tr, meta) {
    const sign = meta.dir === 'in' ? '+' : '-';
    return `<td class="r ${meta.dir}">${sign}${money(tr.value)}</td>`;
}

function kindCell(meta) {
    return `<td><div class="kind ${meta.dir}"><span class="arr">${icon(meta.icon)}</span>${esc(meta.label)}</div></td>`;
}

// ==============================================================================
// RENDER
// ==============================================================================
function renderOverview() {
    const d = S.data;
    if (!d) return;

    $('#ov-name').textContent = d.name || '---';
    $('#ov-id').textContent = 'ID: #' + d.serverId;
    $('#ov-cid').textContent = d.citizenid || '---';
    $('#ov-cash').textContent = money(d.cash);
    $('#ov-bank').textContent = money(d.bank);

    const list = (d.transactions || []).slice(0, 3);
    $('#ov-rows').innerHTML = list.length
        ? list.map(tr => {
            const m = txMeta(tr, d.citizenid);
            return `<tr>${kindCell(m)}<td>${esc(m.note)}</td>${amountCell(tr, m)}</tr>`;
        }).join('')
        : '<tr><td colspan="3" class="empty">Chưa có giao dịch nào</td></tr>';
}

function renderTransactions() {
    const d = S.data;
    if (!d) return;

    const list = d.transactions || [];
    const pages = Math.max(1, Math.ceil(list.length / PER_PAGE));
    if (S.page > pages) S.page = pages;
    if (S.page < 1) S.page = 1;

    const slice = list.slice((S.page - 1) * PER_PAGE, S.page * PER_PAGE);
    $('#tx-rows').innerHTML = slice.length
        ? slice.map(tr => {
            const m = txMeta(tr, d.citizenid);
            return `<tr>${kindCell(m)}<td>${esc(m.who)}</td>${amountCell(tr, m)}<td class="r" style="color:var(--muted)">${fmtDate(tr.ts)}</td></tr>`;
        }).join('')
        : '<tr><td colspan="4" class="empty">Chưa có giao dịch nào</td></tr>';

    $('#pg-label').textContent = `${S.page} / ${pages}`;
    $('#tx-filter').value = String(S.days);
}

function renderSettings() {
    const d = S.data;
    if (!d) return;
    $('#pin-note').textContent = d.hasPin
        ? `Phí đổi PIN: ${money(d.pinCost)} — thay đổi mã PIN để bảo mật tài khoản`
        : 'Bạn chưa có mã PIN — đặt PIN lần đầu hoàn toàn miễn phí';
}

function renderAll() {
    renderOverview();
    renderTransactions();
    renderSettings();
}

function setView(view) {
    S.view = view;
    $$('.nav').forEach(n => n.classList.toggle('active', n.dataset.page === view));
    $$('.page').forEach(p => p.classList.add('hidden'));
    $('#page-' + view).classList.remove('hidden');
}

// ==============================================================================
// MODAL
// ==============================================================================
function closeModal() {
    const m = $('#modal');
    m.classList.add('hidden');
    m.innerHTML = '';
}

function openModal(opts) {
    const m = $('#modal');
    const fields = (opts.fields || []).map(f => `
        <label>${esc(f.label)}
            <input id="mf_${f.id}" type="${f.type || 'text'}" placeholder="${esc(f.placeholder || '')}"
                ${f.max ? `maxlength="${f.max}"` : ''} ${f.mode ? `inputmode="${f.mode}"` : ''} autocomplete="off">
        </label>`).join('');

    m.innerHTML = `
        <div class="mbox">
            <h3>${esc(opts.title)}</h3>
            ${opts.note ? `<div class="mnote">${esc(opts.note)}</div>` : ''}
            ${fields}
            <div class="merr" id="m_err"></div>
            <div class="mrow">
                <button class="btn ghost" id="m_cancel">Hủy</button>
                <button class="btn" id="m_ok">${esc(opts.confirm)}</button>
            </div>
        </div>`;
    m.classList.remove('hidden');

    const submit = () => {
        const values = {};
        (opts.fields || []).forEach(f => { values[f.id] = ($('#mf_' + f.id).value || '').trim(); });
        const err = opts.validate ? opts.validate(values) : null;
        if (err) { $('#m_err').textContent = err; return; }
        opts.onSubmit(values);
        closeModal();
    };

    $('#m_cancel').onclick = closeModal;
    $('#m_ok').onclick = submit;
    $$('.mbox input').forEach(inp => inp.addEventListener('keydown', e => { if (e.key === 'Enter') submit(); }));
    const first = $('.mbox input');
    if (first) setTimeout(() => first.focus(), 30);
}

const validAmount = v => /^\d+$/.test(v) && Number(v) >= 1;

function modalDeposit() {
    openModal({
        title: 'Gửi tiền vào tài khoản',
        fields: [{ id: 'amount', label: 'Số tiền', type: 'number', placeholder: 'Nhập số tiền...' }],
        confirm: 'Xác nhận gửi',
        validate: v => validAmount(v.amount) ? null : 'Số tiền không hợp lệ',
        onSubmit: v => post('deposit', { value: Number(v.amount) }),
    });
}

function modalWithdraw() {
    openModal({
        title: 'Rút tiền mặt',
        fields: [{ id: 'amount', label: 'Số tiền', type: 'number', placeholder: 'Nhập số tiền...' }],
        confirm: 'Xác nhận rút',
        validate: v => validAmount(v.amount) ? null : 'Số tiền không hợp lệ',
        onSubmit: v => post('withdraw', { value: Number(v.amount) }),
    });
}

function modalTransfer() {
    openModal({
        title: 'Chuyển khoản',
        note: 'Nhập Citizen ID của người nhận.',
        fields: [
            { id: 'cid', label: 'Số tài khoản (Citizen ID)', placeholder: 'VD: ABC12345', max: 20 },
            { id: 'amount', label: 'Số tiền', type: 'number', placeholder: 'Nhập số tiền...' },
        ],
        confirm: 'Thực hiện chuyển',
        validate: v => {
            if (!v.cid) return 'Vui lòng nhập Citizen ID người nhận';
            if (!validAmount(v.amount)) return 'Số tiền không hợp lệ';
            return null;
        },
        onSubmit: v => post('transfer', { citizenid: v.cid.toUpperCase(), value: Number(v.amount) }),
    });
}

function modalPin() {
    const d = S.data || {};
    openModal({
        title: 'Đổi mã PIN',
        note: d.hasPin ? `Phí đổi PIN: ${money(d.pinCost)}` : 'Lần đặt PIN đầu tiên miễn phí',
        fields: [{ id: 'pin', label: 'Mã PIN mới (4 chữ số)', type: 'password', mode: 'numeric', max: 4, placeholder: '••••' }],
        confirm: 'Xác nhận đổi PIN',
        validate: v => /^\d{4}$/.test(v.pin) ? null : 'Mã PIN phải gồm đúng 4 chữ số',
        onSubmit: v => post('changePin', { pin: v.pin }),
    });
}

// ==============================================================================
// ATM
// ==============================================================================
let pinInput = '';
let pinBusy = false;

function renderDots(state) {
    $$('.dots i').forEach((dot, i) => {
        dot.className = '';
        if (state === 'ok') dot.classList.add('ok');
        else if (state === 'bad') dot.classList.add('bad');
        else if (i < pinInput.length) dot.classList.add('on');
    });
}

function buildNumpad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'OK'];
    $('#numpad').innerHTML = keys.map(k => `<button data-k="${k}">${k}</button>`).join('');
    $$('#numpad button').forEach(b => b.addEventListener('click', () => pressKey(b.dataset.k)));
}

function pressKey(k) {
    if (pinBusy) return;
    if (k === 'C') {
        pinInput = '';
        renderDots();
    } else if (k === 'OK') {
        if (pinInput.length === 4) submitPin();
    } else if (/^\d$/.test(k) && pinInput.length < 4) {
        pinInput += k;
        renderDots();
    }
}

function submitPin() {
    pinBusy = true;
    post('verifyPin', { pin: pinInput }).then(res => {
        if (res && res.ok) {
            renderDots('ok');
            $('#atm-msg').textContent = 'Xác thực thành công...';
            // Client sẽ gửi message 'open' để chuyển sang giao diện chính
            setTimeout(() => { pinBusy = false; }, 1500);
        } else {
            renderDots('bad');
            $('#atm-msg').textContent = (res && res.locked)
                ? 'Nhập sai quá nhiều lần, vui lòng thử lại sau 30 giây'
                : 'Mã PIN không đúng';
            setTimeout(() => {
                pinInput = '';
                pinBusy = false;
                renderDots();
                $('#atm-msg').textContent = 'Vui lòng nhập 4 chữ số mã PIN';
            }, 900);
        }
    });
}

function showAtm() {
    pinInput = '';
    pinBusy = false;
    renderDots();
    $('#atm-msg').textContent = 'Vui lòng nhập 4 chữ số mã PIN';
    $('#stage').classList.add('hidden');
    $('#atm').classList.remove('hidden');
}

// ==============================================================================
// OPEN / CLOSE / FIT
// ==============================================================================
function fitStage() {
    const s = Math.min(window.innerWidth / 1300, window.innerHeight / 740);
    document.documentElement.style.setProperty('--s', Math.min(s, 1.6));
}

function closeUI() {
    closeModal();
    $('#app').classList.add('hidden');
    $('#stage').classList.add('hidden');
    $('#atm').classList.add('hidden');
    post('close');
}

function applyBankName(name) {
    $$('.bankname').forEach(e => { e.textContent = name; });
}

window.addEventListener('message', e => {
    const m = e.data || {};

    if (m.action === 'open') {
        if (m.bankName) applyBankName(m.bankName);
        $('#app').classList.remove('hidden');
        fitStage();

        if (m.mode === 'atm') {
            showAtm();
            return;
        }

        $('#atm').classList.add('hidden');
        $('#stage').classList.remove('hidden');
        S.data = m.data;
        S.page = 1;
        S.days = 7;
        $('#notifToggle').checked = m.notify !== false;
        setView('overview');
        renderAll();
    } else if (m.action === 'update') {
        S.data = m.data;
        renderAll();
    } else if (m.action === 'close') {
        closeModal();
        $('#app').classList.add('hidden');
    }
});

// ==============================================================================
// EVENTS
// ==============================================================================
function reloadTransactions() {
    post('getData', { days: S.days }).then(res => {
        if (res && res.citizenid) {
            S.data = res;
            S.page = 1;
            renderAll();
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    hydrateIcons();
    buildNumpad();
    fitStage();

    // theme
    try {
        if (localStorage.getItem('qbx_banking_theme') === 'dark') {
            document.body.classList.add('dark');
            $('#themeSelect').value = 'dark';
        }
    } catch (_) { /* bỏ qua */ }

    $$('.nav').forEach(n => n.addEventListener('click', () => setView(n.dataset.page)));
    $('#ov-more').addEventListener('click', () => setView('transactions'));
    $('#logout').addEventListener('click', closeUI);
    $('#atm-close').addEventListener('click', closeUI);

    $('#act-deposit').addEventListener('click', modalDeposit);
    $('#act-withdraw').addEventListener('click', modalWithdraw);
    $('#act-transfer').addEventListener('click', modalTransfer);
    $('#btn-pin').addEventListener('click', modalPin);

    $('#tx-filter').addEventListener('change', e => {
        S.days = Number(e.target.value);
        reloadTransactions();
    });

    $('#pg-prev').addEventListener('click', () => { S.page--; renderTransactions(); });
    $('#pg-next').addEventListener('click', () => { S.page++; renderTransactions(); });
    $('#pg-more').addEventListener('click', () => {
        const pages = Math.max(1, Math.ceil(((S.data && S.data.transactions) || []).length / PER_PAGE));
        S.page = S.page >= pages ? 1 : S.page + 1;
        renderTransactions();
    });

    $('#notifToggle').addEventListener('change', e => post('setNotify', { enabled: e.target.checked }));

    $('#themeSelect').addEventListener('change', e => {
        document.body.classList.toggle('dark', e.target.value === 'dark');
        try { localStorage.setItem('qbx_banking_theme', e.target.value); } catch (_) { /* bỏ qua */ }
    });
});

window.addEventListener('resize', fitStage);

document.addEventListener('keydown', e => {
    if ($('#app').classList.contains('hidden')) return;

    if (e.key === 'Escape') {
        if (!$('#modal').classList.contains('hidden')) closeModal();
        else closeUI();
        return;
    }

    // Bàn phím vật lý cho ATM
    if (!$('#atm').classList.contains('hidden')) {
        if (/^\d$/.test(e.key)) pressKey(e.key);
        else if (e.key === 'Backspace') { pinInput = pinInput.slice(0, -1); renderDots(); }
        else if (e.key === 'Enter') pressKey('OK');
    }
});
