const WATER_KEY = 'water_record_v1';
const MEAL_KEY = 'meal_record_v1';

function pad(n) { return n < 10 ? '0' + n : '' + n; }
function dateKey(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

Page({
  data: {
    nowMl: 0,
    goal: 1500,
    cup: 200,
    percent: 0,
    cups: [150, 200, 250, 300],
    meal: { breakfast: '', lunch: '', dinner: '', snack: '', weight: '' },
    history: [],
    remindOn: false,
    interval: 40,
    todayLabel: ''
  },

  _timer: null,

  onLoad() {
    this.loadWater();
    this.loadMeal();
    this.loadSettings();
    this.buildHistory();
  },

  onShow() {
    this.loadWater();
    this.loadMeal();
    this.buildHistory();
  },

  onUnload() {
    this.stopRemind();
  },

  // ---------- 读取 ----------
  loadWater() {
    const store = wx.getStorageSync(WATER_KEY) || {};
    const goal = wx.getStorageSync('water_goal') || 1500;
    const nowMl = store[dateKey(new Date())] || 0;
    const percent = Math.min(100, Math.round((nowMl / goal) * 100));
    this.setData({ nowMl, goal, percent });
  },

  loadMeal() {
    const store = wx.getStorageSync(MEAL_KEY) || {};
    const m = Object.assign(
      { breakfast: '', lunch: '', dinner: '', snack: '', weight: '' },
      store[dateKey(new Date())] || {}
    );
    this.setData({ meal: m });
  },

  loadSettings() {
    const remindOn = wx.getStorageSync('remind_on') || false;
    const interval = wx.getStorageSync('remind_interval') || 40;
    this.setData({ remindOn, interval });
    if (remindOn) this.startRemind();
  },

  buildHistory() {
    const store = wx.getStorageSync(WATER_KEY) || {};
    const history = [];
    let max = this.data.goal;
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const k = dateKey(d);
      const val = store[k] || 0;
      max = Math.max(max, val);
      history.push({ label: `${d.getMonth() + 1}/${d.getDate()}`, val, today: i === 0, h: 0 });
    }
    history.forEach(h => { h.h = Math.round((h.val / max) * 100); });
    this.setData({ history });
  },

  // ---------- 喝水 ----------
  saveWater(v) {
    const store = wx.getStorageSync(WATER_KEY) || {};
    store[dateKey(new Date())] = Math.max(0, Math.round(v));
    wx.setStorageSync(WATER_KEY, store);
  },

  onCupTap(e) {
    this.setData({ cup: Number(e.currentTarget.dataset.ml) });
  },

  onAdd() {
    const next = this.data.nowMl + this.data.cup;
    this.saveWater(next);
    this.loadWater();
    this.buildHistory();
    wx.showToast({ title: `记录 ${this.data.cup} ml`, icon: 'none' });
  },

  onUndo() {
    this.saveWater(this.data.nowMl - this.data.cup);
    this.loadWater();
    this.buildHistory();
  },

  onReset() {
    wx.showModal({
      title: '重置今日',
      content: '确定清空今日喝水记录吗？',
      success: res => {
        if (res.confirm) {
          this.saveWater(0);
          this.loadWater();
          this.buildHistory();
        }
      }
    });
  },

  onGoalInput(e) {
    const goal = Math.max(800, Math.min(3000, Number(e.detail.value) || 1500));
    wx.setStorageSync('water_goal', goal);
    this.setData({ goal });
    this.loadWater();
    this.buildHistory();
  },

  // ---------- 饮食 ----------
  saveMeal(patch) {
    const store = wx.getStorageSync(MEAL_KEY) || {};
    const k = dateKey(new Date());
    store[k] = Object.assign(this.data.meal, patch);
    wx.setStorageSync(MEAL_KEY, store);
    this.setData({ meal: store[k] });
  },

  onMealInput(e) {
    const field = e.currentTarget.dataset.field;
    this.saveMeal({ [field]: e.detail.value });
  },

  onWeightInput(e) {
    this.saveMeal({ weight: e.detail.value });
  },

  // ---------- 提醒 ----------
  startRemind() {
    this.stopRemind();
    const min = Math.max(15, Number(this.data.interval) || 40);
    this._timer = setInterval(() => {
      wx.showToast({ title: '该喝一杯水啦', icon: 'none' });
    }, min * 60 * 1000);
  },

  stopRemind() {
    if (this._timer) { clearInterval(this._timer); this._timer = null; }
  },

  onRemindChange(e) {
    const remindOn = e.detail.value;
    wx.setStorageSync('remind_on', remindOn);
    this.setData({ remindOn });
    if (remindOn) this.startRemind(); else this.stopRemind();
  },

  onIntervalInput(e) {
    const interval = Math.max(15, Math.min(120, Number(e.detail.value) || 40));
    wx.setStorageSync('remind_interval', interval);
    this.setData({ interval });
    if (this.data.remindOn) this.startRemind();
  }
});
