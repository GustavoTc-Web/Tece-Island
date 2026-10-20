// Authoritative slots use the same seven base slots and stack limit as ResourceInventory.
export class Inventory {
  constructor() {
    this.slots=[{item:'machado_madeira',quantity:1},{item:'picareta_madeira',quantity:1},{item:'cantil',quantity:1,water:0},{},{},{},{}];
    this.selected=0;
  }
  count(item) {return this.slots.reduce((sum,s)=>sum+(s.item===item?s.quantity:0),0);}
  valid(index) {return Number.isInteger(index)&&index>=0&&index<this.slots.length;}
  tool() {const item=this.slots[this.selected]?.item;return ['machado_madeira','picareta_madeira'].includes(item)?item:'maos';}
  select(index) {if(index!==-1&&!this.valid(index))return 'invalid_slot';this.selected=index;return null;}
  equip(tool) {
    if(tool==='maos')return this.select(-1);
    const index=this.slots.findIndex(s=>s.item===tool);
    return index<0||!['machado_madeira','picareta_madeira'].includes(tool)?'invalid_tool':this.select(index);
  }
  swap(a,b) {
    if(!this.valid(a)||!this.valid(b))return 'invalid_slot';
    [this.slots[a],this.slots[b]]=[this.slots[b],this.slots[a]];
    if(this.selected===a)this.selected=b;else if(this.selected===b)this.selected=a;
    return null;
  }
  add(item,amount) {
    const next=this.slots.map(s=>({...s}));let remaining=amount;
    for(const s of next)if(s.item===item){const n=Math.min(remaining,15-s.quantity);s.quantity+=n;remaining-=n;}
    for(let i=0;i<next.length&&remaining;i++)if(!next[i].item){const n=Math.min(remaining,15);next[i]={item,quantity:n};remaining-=n;}
    if(remaining)return false;
    this.slots=next;return true;
  }
  fill() {
    const chosen=this.slots[this.selected];
    const s=chosen?.item==='cantil'&&chosen.water<3?chosen:this.slots.find(s=>s.item==='cantil'&&s.water<3);
    if(!s)return 'canteen_unavailable';s.water=3;return null;
  }
  use(index) {
    if(!this.valid(index))return 'invalid_slot';const s=this.slots[index];
    if(s.item!=='cantil')return 'invalid_item';
    if(!(s.water>0))return 'canteen_empty';s.water--;return null;
  }
  counts() {return Object.fromEntries(['machado_madeira','picareta_madeira','cantil','madeira','pedra','fibra'].map(i=>[i,this.count(i)]));}
  snapshot() {
    const tool=this.tool();
    return {slots:this.slots.map(s=>({...s})),selected:this.selected,category:tool==='maos'?'maos':(tool.startsWith('machado')?'machado':'picareta'),weapon_uid:0,backpack:{},armor:{}};
  }
}
