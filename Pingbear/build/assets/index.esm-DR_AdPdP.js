import{g as lu,_ as cu,a as fu,b as du,i as vo,p as mu,u as gu,d as pu,c as _u,F as yu,L as Eu,e as xt,f as Tu,h as vu,S as Iu,j as Au,C as wu,r as Ii,k as Ru}from"./index-ChDvtoaM.js";var Ai=typeof globalThis<"u"?globalThis:typeof window<"u"?window:typeof global<"u"?global:typeof self<"u"?self:{};/** @license
Copyright The Closure Library Authors.
SPDX-License-Identifier: Apache-2.0
*/var Bt,Io;(function(){var s;/** @license

 Copyright The Closure Library Authors.
 SPDX-License-Identifier: Apache-2.0
*/function t(T,m){function p(){}p.prototype=m.prototype,T.D=m.prototype,T.prototype=new p,T.prototype.constructor=T,T.C=function(y,E,I){for(var g=Array(arguments.length-2),Nt=2;Nt<arguments.length;Nt++)g[Nt-2]=arguments[Nt];return m.prototype[E].apply(y,g)}}function e(){this.blockSize=-1}function n(){this.blockSize=-1,this.blockSize=64,this.g=Array(4),this.B=Array(this.blockSize),this.o=this.h=0,this.s()}t(n,e),n.prototype.s=function(){this.g[0]=1732584193,this.g[1]=4023233417,this.g[2]=2562383102,this.g[3]=271733878,this.o=this.h=0};function i(T,m,p){p||(p=0);var y=Array(16);if(typeof m=="string")for(var E=0;16>E;++E)y[E]=m.charCodeAt(p++)|m.charCodeAt(p++)<<8|m.charCodeAt(p++)<<16|m.charCodeAt(p++)<<24;else for(E=0;16>E;++E)y[E]=m[p++]|m[p++]<<8|m[p++]<<16|m[p++]<<24;m=T.g[0],p=T.g[1],E=T.g[2];var I=T.g[3],g=m+(I^p&(E^I))+y[0]+3614090360&4294967295;m=p+(g<<7&4294967295|g>>>25),g=I+(E^m&(p^E))+y[1]+3905402710&4294967295,I=m+(g<<12&4294967295|g>>>20),g=E+(p^I&(m^p))+y[2]+606105819&4294967295,E=I+(g<<17&4294967295|g>>>15),g=p+(m^E&(I^m))+y[3]+3250441966&4294967295,p=E+(g<<22&4294967295|g>>>10),g=m+(I^p&(E^I))+y[4]+4118548399&4294967295,m=p+(g<<7&4294967295|g>>>25),g=I+(E^m&(p^E))+y[5]+1200080426&4294967295,I=m+(g<<12&4294967295|g>>>20),g=E+(p^I&(m^p))+y[6]+2821735955&4294967295,E=I+(g<<17&4294967295|g>>>15),g=p+(m^E&(I^m))+y[7]+4249261313&4294967295,p=E+(g<<22&4294967295|g>>>10),g=m+(I^p&(E^I))+y[8]+1770035416&4294967295,m=p+(g<<7&4294967295|g>>>25),g=I+(E^m&(p^E))+y[9]+2336552879&4294967295,I=m+(g<<12&4294967295|g>>>20),g=E+(p^I&(m^p))+y[10]+4294925233&4294967295,E=I+(g<<17&4294967295|g>>>15),g=p+(m^E&(I^m))+y[11]+2304563134&4294967295,p=E+(g<<22&4294967295|g>>>10),g=m+(I^p&(E^I))+y[12]+1804603682&4294967295,m=p+(g<<7&4294967295|g>>>25),g=I+(E^m&(p^E))+y[13]+4254626195&4294967295,I=m+(g<<12&4294967295|g>>>20),g=E+(p^I&(m^p))+y[14]+2792965006&4294967295,E=I+(g<<17&4294967295|g>>>15),g=p+(m^E&(I^m))+y[15]+1236535329&4294967295,p=E+(g<<22&4294967295|g>>>10),g=m+(E^I&(p^E))+y[1]+4129170786&4294967295,m=p+(g<<5&4294967295|g>>>27),g=I+(p^E&(m^p))+y[6]+3225465664&4294967295,I=m+(g<<9&4294967295|g>>>23),g=E+(m^p&(I^m))+y[11]+643717713&4294967295,E=I+(g<<14&4294967295|g>>>18),g=p+(I^m&(E^I))+y[0]+3921069994&4294967295,p=E+(g<<20&4294967295|g>>>12),g=m+(E^I&(p^E))+y[5]+3593408605&4294967295,m=p+(g<<5&4294967295|g>>>27),g=I+(p^E&(m^p))+y[10]+38016083&4294967295,I=m+(g<<9&4294967295|g>>>23),g=E+(m^p&(I^m))+y[15]+3634488961&4294967295,E=I+(g<<14&4294967295|g>>>18),g=p+(I^m&(E^I))+y[4]+3889429448&4294967295,p=E+(g<<20&4294967295|g>>>12),g=m+(E^I&(p^E))+y[9]+568446438&4294967295,m=p+(g<<5&4294967295|g>>>27),g=I+(p^E&(m^p))+y[14]+3275163606&4294967295,I=m+(g<<9&4294967295|g>>>23),g=E+(m^p&(I^m))+y[3]+4107603335&4294967295,E=I+(g<<14&4294967295|g>>>18),g=p+(I^m&(E^I))+y[8]+1163531501&4294967295,p=E+(g<<20&4294967295|g>>>12),g=m+(E^I&(p^E))+y[13]+2850285829&4294967295,m=p+(g<<5&4294967295|g>>>27),g=I+(p^E&(m^p))+y[2]+4243563512&4294967295,I=m+(g<<9&4294967295|g>>>23),g=E+(m^p&(I^m))+y[7]+1735328473&4294967295,E=I+(g<<14&4294967295|g>>>18),g=p+(I^m&(E^I))+y[12]+2368359562&4294967295,p=E+(g<<20&4294967295|g>>>12),g=m+(p^E^I)+y[5]+4294588738&4294967295,m=p+(g<<4&4294967295|g>>>28),g=I+(m^p^E)+y[8]+2272392833&4294967295,I=m+(g<<11&4294967295|g>>>21),g=E+(I^m^p)+y[11]+1839030562&4294967295,E=I+(g<<16&4294967295|g>>>16),g=p+(E^I^m)+y[14]+4259657740&4294967295,p=E+(g<<23&4294967295|g>>>9),g=m+(p^E^I)+y[1]+2763975236&4294967295,m=p+(g<<4&4294967295|g>>>28),g=I+(m^p^E)+y[4]+1272893353&4294967295,I=m+(g<<11&4294967295|g>>>21),g=E+(I^m^p)+y[7]+4139469664&4294967295,E=I+(g<<16&4294967295|g>>>16),g=p+(E^I^m)+y[10]+3200236656&4294967295,p=E+(g<<23&4294967295|g>>>9),g=m+(p^E^I)+y[13]+681279174&4294967295,m=p+(g<<4&4294967295|g>>>28),g=I+(m^p^E)+y[0]+3936430074&4294967295,I=m+(g<<11&4294967295|g>>>21),g=E+(I^m^p)+y[3]+3572445317&4294967295,E=I+(g<<16&4294967295|g>>>16),g=p+(E^I^m)+y[6]+76029189&4294967295,p=E+(g<<23&4294967295|g>>>9),g=m+(p^E^I)+y[9]+3654602809&4294967295,m=p+(g<<4&4294967295|g>>>28),g=I+(m^p^E)+y[12]+3873151461&4294967295,I=m+(g<<11&4294967295|g>>>21),g=E+(I^m^p)+y[15]+530742520&4294967295,E=I+(g<<16&4294967295|g>>>16),g=p+(E^I^m)+y[2]+3299628645&4294967295,p=E+(g<<23&4294967295|g>>>9),g=m+(E^(p|~I))+y[0]+4096336452&4294967295,m=p+(g<<6&4294967295|g>>>26),g=I+(p^(m|~E))+y[7]+1126891415&4294967295,I=m+(g<<10&4294967295|g>>>22),g=E+(m^(I|~p))+y[14]+2878612391&4294967295,E=I+(g<<15&4294967295|g>>>17),g=p+(I^(E|~m))+y[5]+4237533241&4294967295,p=E+(g<<21&4294967295|g>>>11),g=m+(E^(p|~I))+y[12]+1700485571&4294967295,m=p+(g<<6&4294967295|g>>>26),g=I+(p^(m|~E))+y[3]+2399980690&4294967295,I=m+(g<<10&4294967295|g>>>22),g=E+(m^(I|~p))+y[10]+4293915773&4294967295,E=I+(g<<15&4294967295|g>>>17),g=p+(I^(E|~m))+y[1]+2240044497&4294967295,p=E+(g<<21&4294967295|g>>>11),g=m+(E^(p|~I))+y[8]+1873313359&4294967295,m=p+(g<<6&4294967295|g>>>26),g=I+(p^(m|~E))+y[15]+4264355552&4294967295,I=m+(g<<10&4294967295|g>>>22),g=E+(m^(I|~p))+y[6]+2734768916&4294967295,E=I+(g<<15&4294967295|g>>>17),g=p+(I^(E|~m))+y[13]+1309151649&4294967295,p=E+(g<<21&4294967295|g>>>11),g=m+(E^(p|~I))+y[4]+4149444226&4294967295,m=p+(g<<6&4294967295|g>>>26),g=I+(p^(m|~E))+y[11]+3174756917&4294967295,I=m+(g<<10&4294967295|g>>>22),g=E+(m^(I|~p))+y[2]+718787259&4294967295,E=I+(g<<15&4294967295|g>>>17),g=p+(I^(E|~m))+y[9]+3951481745&4294967295,T.g[0]=T.g[0]+m&4294967295,T.g[1]=T.g[1]+(E+(g<<21&4294967295|g>>>11))&4294967295,T.g[2]=T.g[2]+E&4294967295,T.g[3]=T.g[3]+I&4294967295}n.prototype.u=function(T,m){m===void 0&&(m=T.length);for(var p=m-this.blockSize,y=this.B,E=this.h,I=0;I<m;){if(E==0)for(;I<=p;)i(this,T,I),I+=this.blockSize;if(typeof T=="string"){for(;I<m;)if(y[E++]=T.charCodeAt(I++),E==this.blockSize){i(this,y),E=0;break}}else for(;I<m;)if(y[E++]=T[I++],E==this.blockSize){i(this,y),E=0;break}}this.h=E,this.o+=m},n.prototype.v=function(){var T=Array((56>this.h?this.blockSize:2*this.blockSize)-this.h);T[0]=128;for(var m=1;m<T.length-8;++m)T[m]=0;var p=8*this.o;for(m=T.length-8;m<T.length;++m)T[m]=p&255,p/=256;for(this.u(T),T=Array(16),m=p=0;4>m;++m)for(var y=0;32>y;y+=8)T[p++]=this.g[m]>>>y&255;return T};function o(T,m){var p=l;return Object.prototype.hasOwnProperty.call(p,T)?p[T]:p[T]=m(T)}function u(T,m){this.h=m;for(var p=[],y=!0,E=T.length-1;0<=E;E--){var I=T[E]|0;y&&I==m||(p[E]=I,y=!1)}this.g=p}var l={};function f(T){return-128<=T&&128>T?o(T,function(m){return new u([m|0],0>m?-1:0)}):new u([T|0],0>T?-1:0)}function d(T){if(isNaN(T)||!isFinite(T))return w;if(0>T)return N(d(-T));for(var m=[],p=1,y=0;T>=p;y++)m[y]=T/p|0,p*=4294967296;return new u(m,0)}function _(T,m){if(T.length==0)throw Error("number format error: empty string");if(m=m||10,2>m||36<m)throw Error("radix out of range: "+m);if(T.charAt(0)=="-")return N(_(T.substring(1),m));if(0<=T.indexOf("-"))throw Error('number format error: interior "-" character');for(var p=d(Math.pow(m,8)),y=w,E=0;E<T.length;E+=8){var I=Math.min(8,T.length-E),g=parseInt(T.substring(E,E+I),m);8>I?(I=d(Math.pow(m,I)),y=y.j(I).add(d(g))):(y=y.j(p),y=y.add(d(g)))}return y}var w=f(0),P=f(1),C=f(16777216);s=u.prototype,s.m=function(){if(M(this))return-N(this).m();for(var T=0,m=1,p=0;p<this.g.length;p++){var y=this.i(p);T+=(0<=y?y:4294967296+y)*m,m*=4294967296}return T},s.toString=function(T){if(T=T||10,2>T||36<T)throw Error("radix out of range: "+T);if(b(this))return"0";if(M(this))return"-"+N(this).toString(T);for(var m=d(Math.pow(T,6)),p=this,y="";;){var E=st(p,m).g;p=et(p,E.j(m));var I=((0<p.g.length?p.g[0]:p.h)>>>0).toString(T);if(p=E,b(p))return I+y;for(;6>I.length;)I="0"+I;y=I+y}},s.i=function(T){return 0>T?0:T<this.g.length?this.g[T]:this.h};function b(T){if(T.h!=0)return!1;for(var m=0;m<T.g.length;m++)if(T.g[m]!=0)return!1;return!0}function M(T){return T.h==-1}s.l=function(T){return T=et(this,T),M(T)?-1:b(T)?0:1};function N(T){for(var m=T.g.length,p=[],y=0;y<m;y++)p[y]=~T.g[y];return new u(p,~T.h).add(P)}s.abs=function(){return M(this)?N(this):this},s.add=function(T){for(var m=Math.max(this.g.length,T.g.length),p=[],y=0,E=0;E<=m;E++){var I=y+(this.i(E)&65535)+(T.i(E)&65535),g=(I>>>16)+(this.i(E)>>>16)+(T.i(E)>>>16);y=g>>>16,I&=65535,g&=65535,p[E]=g<<16|I}return new u(p,p[p.length-1]&-2147483648?-1:0)};function et(T,m){return T.add(N(m))}s.j=function(T){if(b(this)||b(T))return w;if(M(this))return M(T)?N(this).j(N(T)):N(N(this).j(T));if(M(T))return N(this.j(N(T)));if(0>this.l(C)&&0>T.l(C))return d(this.m()*T.m());for(var m=this.g.length+T.g.length,p=[],y=0;y<2*m;y++)p[y]=0;for(y=0;y<this.g.length;y++)for(var E=0;E<T.g.length;E++){var I=this.i(y)>>>16,g=this.i(y)&65535,Nt=T.i(E)>>>16,Se=T.i(E)&65535;p[2*y+2*E]+=g*Se,G(p,2*y+2*E),p[2*y+2*E+1]+=I*Se,G(p,2*y+2*E+1),p[2*y+2*E+1]+=g*Nt,G(p,2*y+2*E+1),p[2*y+2*E+2]+=I*Nt,G(p,2*y+2*E+2)}for(y=0;y<m;y++)p[y]=p[2*y+1]<<16|p[2*y];for(y=m;y<2*m;y++)p[y]=0;return new u(p,0)};function G(T,m){for(;(T[m]&65535)!=T[m];)T[m+1]+=T[m]>>>16,T[m]&=65535,m++}function K(T,m){this.g=T,this.h=m}function st(T,m){if(b(m))throw Error("division by zero");if(b(T))return new K(w,w);if(M(T))return m=st(N(T),m),new K(N(m.g),N(m.h));if(M(m))return m=st(T,N(m)),new K(N(m.g),m.h);if(30<T.g.length){if(M(T)||M(m))throw Error("slowDivide_ only works with positive integers.");for(var p=P,y=m;0>=y.l(T);)p=Dt(p),y=Dt(y);var E=ot(p,1),I=ot(y,1);for(y=ot(y,2),p=ot(p,2);!b(y);){var g=I.add(y);0>=g.l(T)&&(E=E.add(p),I=g),y=ot(y,1),p=ot(p,1)}return m=et(T,E.j(m)),new K(E,m)}for(E=w;0<=T.l(m);){for(p=Math.max(1,Math.floor(T.m()/m.m())),y=Math.ceil(Math.log(p)/Math.LN2),y=48>=y?1:Math.pow(2,y-48),I=d(p),g=I.j(m);M(g)||0<g.l(T);)p-=y,I=d(p),g=I.j(m);b(I)&&(I=P),E=E.add(I),T=et(T,g)}return new K(E,T)}s.A=function(T){return st(this,T).h},s.and=function(T){for(var m=Math.max(this.g.length,T.g.length),p=[],y=0;y<m;y++)p[y]=this.i(y)&T.i(y);return new u(p,this.h&T.h)},s.or=function(T){for(var m=Math.max(this.g.length,T.g.length),p=[],y=0;y<m;y++)p[y]=this.i(y)|T.i(y);return new u(p,this.h|T.h)},s.xor=function(T){for(var m=Math.max(this.g.length,T.g.length),p=[],y=0;y<m;y++)p[y]=this.i(y)^T.i(y);return new u(p,this.h^T.h)};function Dt(T){for(var m=T.g.length+1,p=[],y=0;y<m;y++)p[y]=T.i(y)<<1|T.i(y-1)>>>31;return new u(p,T.h)}function ot(T,m){var p=m>>5;m%=32;for(var y=T.g.length-p,E=[],I=0;I<y;I++)E[I]=0<m?T.i(I+p)>>>m|T.i(I+p+1)<<32-m:T.i(I+p);return new u(E,T.h)}n.prototype.digest=n.prototype.v,n.prototype.reset=n.prototype.s,n.prototype.update=n.prototype.u,Io=n,u.prototype.add=u.prototype.add,u.prototype.multiply=u.prototype.j,u.prototype.modulo=u.prototype.A,u.prototype.compare=u.prototype.l,u.prototype.toNumber=u.prototype.m,u.prototype.toString=u.prototype.toString,u.prototype.getBits=u.prototype.i,u.fromNumber=d,u.fromString=_,Bt=u}).apply(typeof Ai<"u"?Ai:typeof self<"u"?self:typeof window<"u"?window:{});var Cn=typeof globalThis<"u"?globalThis:typeof window<"u"?window:typeof global<"u"?global:typeof self<"u"?self:{};/** @license
Copyright The Closure Library Authors.
SPDX-License-Identifier: Apache-2.0
*/var Ao,Ge,wo,xn,br,Ro,Po,So;(function(){var s,t=typeof Object.defineProperties=="function"?Object.defineProperty:function(r,a,h){return r==Array.prototype||r==Object.prototype||(r[a]=h.value),r};function e(r){r=[typeof globalThis=="object"&&globalThis,r,typeof window=="object"&&window,typeof self=="object"&&self,typeof Cn=="object"&&Cn];for(var a=0;a<r.length;++a){var h=r[a];if(h&&h.Math==Math)return h}throw Error("Cannot find global object")}var n=e(this);function i(r,a){if(a)t:{var h=n;r=r.split(".");for(var c=0;c<r.length-1;c++){var v=r[c];if(!(v in h))break t;h=h[v]}r=r[r.length-1],c=h[r],a=a(c),a!=c&&a!=null&&t(h,r,{configurable:!0,writable:!0,value:a})}}function o(r,a){r instanceof String&&(r+="");var h=0,c=!1,v={next:function(){if(!c&&h<r.length){var A=h++;return{value:a(A,r[A]),done:!1}}return c=!0,{done:!0,value:void 0}}};return v[Symbol.iterator]=function(){return v},v}i("Array.prototype.values",function(r){return r||function(){return o(this,function(a,h){return h})}});/** @license

 Copyright The Closure Library Authors.
 SPDX-License-Identifier: Apache-2.0
*/var u=u||{},l=this||self;function f(r){var a=typeof r;return a=a!="object"?a:r?Array.isArray(r)?"array":a:"null",a=="array"||a=="object"&&typeof r.length=="number"}function d(r){var a=typeof r;return a=="object"&&r!=null||a=="function"}function _(r,a,h){return r.call.apply(r.bind,arguments)}function w(r,a,h){if(!r)throw Error();if(2<arguments.length){var c=Array.prototype.slice.call(arguments,2);return function(){var v=Array.prototype.slice.call(arguments);return Array.prototype.unshift.apply(v,c),r.apply(a,v)}}return function(){return r.apply(a,arguments)}}function P(r,a,h){return P=Function.prototype.bind&&Function.prototype.bind.toString().indexOf("native code")!=-1?_:w,P.apply(null,arguments)}function C(r,a){var h=Array.prototype.slice.call(arguments,1);return function(){var c=h.slice();return c.push.apply(c,arguments),r.apply(this,c)}}function b(r,a){function h(){}h.prototype=a.prototype,r.aa=a.prototype,r.prototype=new h,r.prototype.constructor=r,r.Qb=function(c,v,A){for(var V=Array(arguments.length-2),z=2;z<arguments.length;z++)V[z-2]=arguments[z];return a.prototype[v].apply(c,V)}}function M(r){const a=r.length;if(0<a){const h=Array(a);for(let c=0;c<a;c++)h[c]=r[c];return h}return[]}function N(r,a){for(let h=1;h<arguments.length;h++){const c=arguments[h];if(f(c)){const v=r.length||0,A=c.length||0;r.length=v+A;for(let V=0;V<A;V++)r[v+V]=c[V]}else r.push(c)}}class et{constructor(a,h){this.i=a,this.j=h,this.h=0,this.g=null}get(){let a;return 0<this.h?(this.h--,a=this.g,this.g=a.next,a.next=null):a=this.i(),a}}function G(r){return/^[\s\xa0]*$/.test(r)}function K(){var r=l.navigator;return r&&(r=r.userAgent)?r:""}function st(r){return st[" "](r),r}st[" "]=function(){};var Dt=K().indexOf("Gecko")!=-1&&!(K().toLowerCase().indexOf("webkit")!=-1&&K().indexOf("Edge")==-1)&&!(K().indexOf("Trident")!=-1||K().indexOf("MSIE")!=-1)&&K().indexOf("Edge")==-1;function ot(r,a,h){for(const c in r)a.call(h,r[c],c,r)}function T(r,a){for(const h in r)a.call(void 0,r[h],h,r)}function m(r){const a={};for(const h in r)a[h]=r[h];return a}const p="constructor hasOwnProperty isPrototypeOf propertyIsEnumerable toLocaleString toString valueOf".split(" ");function y(r,a){let h,c;for(let v=1;v<arguments.length;v++){c=arguments[v];for(h in c)r[h]=c[h];for(let A=0;A<p.length;A++)h=p[A],Object.prototype.hasOwnProperty.call(c,h)&&(r[h]=c[h])}}function E(r){var a=1;r=r.split(":");const h=[];for(;0<a&&r.length;)h.push(r.shift()),a--;return r.length&&h.push(r.join(":")),h}function I(r){l.setTimeout(()=>{throw r},0)}function g(){var r=rr;let a=null;return r.g&&(a=r.g,r.g=r.g.next,r.g||(r.h=null),a.next=null),a}class Nt{constructor(){this.h=this.g=null}add(a,h){const c=Se.get();c.set(a,h),this.h?this.h.next=c:this.g=c,this.h=c}}var Se=new et(()=>new Ca,r=>r.reset());class Ca{constructor(){this.next=this.g=this.h=null}set(a,h){this.h=a,this.g=h,this.next=null}reset(){this.next=this.g=this.h=null}}let Ve,Ce=!1,rr=new Nt,Is=()=>{const r=l.Promise.resolve(void 0);Ve=()=>{r.then(Da)}};var Da=()=>{for(var r;r=g();){try{r.h.call(r.g)}catch(h){I(h)}var a=Se;a.j(r),100>a.h&&(a.h++,r.next=a.g,a.g=r)}Ce=!1};function Mt(){this.s=this.s,this.C=this.C}Mt.prototype.s=!1,Mt.prototype.ma=function(){this.s||(this.s=!0,this.N())},Mt.prototype.N=function(){if(this.C)for(;this.C.length;)this.C.shift()()};function lt(r,a){this.type=r,this.g=this.target=a,this.defaultPrevented=!1}lt.prototype.h=function(){this.defaultPrevented=!0};var Na=function(){if(!l.addEventListener||!Object.defineProperty)return!1;var r=!1,a=Object.defineProperty({},"passive",{get:function(){r=!0}});try{const h=()=>{};l.addEventListener("test",h,a),l.removeEventListener("test",h,a)}catch{}return r}();function De(r,a){if(lt.call(this,r?r.type:""),this.relatedTarget=this.g=this.target=null,this.button=this.screenY=this.screenX=this.clientY=this.clientX=0,this.key="",this.metaKey=this.shiftKey=this.altKey=this.ctrlKey=!1,this.state=null,this.pointerId=0,this.pointerType="",this.i=null,r){var h=this.type=r.type,c=r.changedTouches&&r.changedTouches.length?r.changedTouches[0]:null;if(this.target=r.target||r.srcElement,this.g=a,a=r.relatedTarget){if(Dt){t:{try{st(a.nodeName);var v=!0;break t}catch{}v=!1}v||(a=null)}}else h=="mouseover"?a=r.fromElement:h=="mouseout"&&(a=r.toElement);this.relatedTarget=a,c?(this.clientX=c.clientX!==void 0?c.clientX:c.pageX,this.clientY=c.clientY!==void 0?c.clientY:c.pageY,this.screenX=c.screenX||0,this.screenY=c.screenY||0):(this.clientX=r.clientX!==void 0?r.clientX:r.pageX,this.clientY=r.clientY!==void 0?r.clientY:r.pageY,this.screenX=r.screenX||0,this.screenY=r.screenY||0),this.button=r.button,this.key=r.key||"",this.ctrlKey=r.ctrlKey,this.altKey=r.altKey,this.shiftKey=r.shiftKey,this.metaKey=r.metaKey,this.pointerId=r.pointerId||0,this.pointerType=typeof r.pointerType=="string"?r.pointerType:ka[r.pointerType]||"",this.state=r.state,this.i=r,r.defaultPrevented&&De.aa.h.call(this)}}b(De,lt);var ka={2:"touch",3:"pen",4:"mouse"};De.prototype.h=function(){De.aa.h.call(this);var r=this.i;r.preventDefault?r.preventDefault():r.returnValue=!1};var ln="closure_listenable_"+(1e6*Math.random()|0),ba=0;function xa(r,a,h,c,v){this.listener=r,this.proxy=null,this.src=a,this.type=h,this.capture=!!c,this.ha=v,this.key=++ba,this.da=this.fa=!1}function cn(r){r.da=!0,r.listener=null,r.proxy=null,r.src=null,r.ha=null}function fn(r){this.src=r,this.g={},this.h=0}fn.prototype.add=function(r,a,h,c,v){var A=r.toString();r=this.g[A],r||(r=this.g[A]=[],this.h++);var V=ir(r,a,c,v);return-1<V?(a=r[V],h||(a.fa=!1)):(a=new xa(a,this.src,A,!!c,v),a.fa=h,r.push(a)),a};function sr(r,a){var h=a.type;if(h in r.g){var c=r.g[h],v=Array.prototype.indexOf.call(c,a,void 0),A;(A=0<=v)&&Array.prototype.splice.call(c,v,1),A&&(cn(a),r.g[h].length==0&&(delete r.g[h],r.h--))}}function ir(r,a,h,c){for(var v=0;v<r.length;++v){var A=r[v];if(!A.da&&A.listener==a&&A.capture==!!h&&A.ha==c)return v}return-1}var or="closure_lm_"+(1e6*Math.random()|0),ar={};function As(r,a,h,c,v){if(Array.isArray(a)){for(var A=0;A<a.length;A++)As(r,a[A],h,c,v);return null}return h=Ps(h),r&&r[ln]?r.K(a,h,d(c)?!!c.capture:!1,v):Oa(r,a,h,!1,c,v)}function Oa(r,a,h,c,v,A){if(!a)throw Error("Invalid event type");var V=d(v)?!!v.capture:!!v,z=hr(r);if(z||(r[or]=z=new fn(r)),h=z.add(a,h,c,V,A),h.proxy)return h;if(c=Ma(),h.proxy=c,c.src=r,c.listener=h,r.addEventListener)Na||(v=V),v===void 0&&(v=!1),r.addEventListener(a.toString(),c,v);else if(r.attachEvent)r.attachEvent(Rs(a.toString()),c);else if(r.addListener&&r.removeListener)r.addListener(c);else throw Error("addEventListener and attachEvent are unavailable.");return h}function Ma(){function r(h){return a.call(r.src,r.listener,h)}const a=La;return r}function ws(r,a,h,c,v){if(Array.isArray(a))for(var A=0;A<a.length;A++)ws(r,a[A],h,c,v);else c=d(c)?!!c.capture:!!c,h=Ps(h),r&&r[ln]?(r=r.i,a=String(a).toString(),a in r.g&&(A=r.g[a],h=ir(A,h,c,v),-1<h&&(cn(A[h]),Array.prototype.splice.call(A,h,1),A.length==0&&(delete r.g[a],r.h--)))):r&&(r=hr(r))&&(a=r.g[a.toString()],r=-1,a&&(r=ir(a,h,c,v)),(h=-1<r?a[r]:null)&&ur(h))}function ur(r){if(typeof r!="number"&&r&&!r.da){var a=r.src;if(a&&a[ln])sr(a.i,r);else{var h=r.type,c=r.proxy;a.removeEventListener?a.removeEventListener(h,c,r.capture):a.detachEvent?a.detachEvent(Rs(h),c):a.addListener&&a.removeListener&&a.removeListener(c),(h=hr(a))?(sr(h,r),h.h==0&&(h.src=null,a[or]=null)):cn(r)}}}function Rs(r){return r in ar?ar[r]:ar[r]="on"+r}function La(r,a){if(r.da)r=!0;else{a=new De(a,this);var h=r.listener,c=r.ha||r.src;r.fa&&ur(r),r=h.call(c,a)}return r}function hr(r){return r=r[or],r instanceof fn?r:null}var lr="__closure_events_fn_"+(1e9*Math.random()>>>0);function Ps(r){return typeof r=="function"?r:(r[lr]||(r[lr]=function(a){return r.handleEvent(a)}),r[lr])}function ct(){Mt.call(this),this.i=new fn(this),this.M=this,this.F=null}b(ct,Mt),ct.prototype[ln]=!0,ct.prototype.removeEventListener=function(r,a,h,c){ws(this,r,a,h,c)};function _t(r,a){var h,c=r.F;if(c)for(h=[];c;c=c.F)h.push(c);if(r=r.M,c=a.type||a,typeof a=="string")a=new lt(a,r);else if(a instanceof lt)a.target=a.target||r;else{var v=a;a=new lt(c,r),y(a,v)}if(v=!0,h)for(var A=h.length-1;0<=A;A--){var V=a.g=h[A];v=dn(V,c,!0,a)&&v}if(V=a.g=r,v=dn(V,c,!0,a)&&v,v=dn(V,c,!1,a)&&v,h)for(A=0;A<h.length;A++)V=a.g=h[A],v=dn(V,c,!1,a)&&v}ct.prototype.N=function(){if(ct.aa.N.call(this),this.i){var r=this.i,a;for(a in r.g){for(var h=r.g[a],c=0;c<h.length;c++)cn(h[c]);delete r.g[a],r.h--}}this.F=null},ct.prototype.K=function(r,a,h,c){return this.i.add(String(r),a,!1,h,c)},ct.prototype.L=function(r,a,h,c){return this.i.add(String(r),a,!0,h,c)};function dn(r,a,h,c){if(a=r.i.g[String(a)],!a)return!0;a=a.concat();for(var v=!0,A=0;A<a.length;++A){var V=a[A];if(V&&!V.da&&V.capture==h){var z=V.listener,at=V.ha||V.src;V.fa&&sr(r.i,V),v=z.call(at,c)!==!1&&v}}return v&&!c.defaultPrevented}function Ss(r,a,h){if(typeof r=="function")h&&(r=P(r,h));else if(r&&typeof r.handleEvent=="function")r=P(r.handleEvent,r);else throw Error("Invalid listener argument");return 2147483647<Number(a)?-1:l.setTimeout(r,a||0)}function Vs(r){r.g=Ss(()=>{r.g=null,r.i&&(r.i=!1,Vs(r))},r.l);const a=r.h;r.h=null,r.m.apply(null,a)}class Fa extends Mt{constructor(a,h){super(),this.m=a,this.l=h,this.h=null,this.i=!1,this.g=null}j(a){this.h=arguments,this.g?this.i=!0:Vs(this)}N(){super.N(),this.g&&(l.clearTimeout(this.g),this.g=null,this.i=!1,this.h=null)}}function Ne(r){Mt.call(this),this.h=r,this.g={}}b(Ne,Mt);var Cs=[];function Ds(r){ot(r.g,function(a,h){this.g.hasOwnProperty(h)&&ur(a)},r),r.g={}}Ne.prototype.N=function(){Ne.aa.N.call(this),Ds(this)},Ne.prototype.handleEvent=function(){throw Error("EventHandler.handleEvent not implemented")};var cr=l.JSON.stringify,Ua=l.JSON.parse,qa=class{stringify(r){return l.JSON.stringify(r,void 0)}parse(r){return l.JSON.parse(r,void 0)}};function fr(){}fr.prototype.h=null;function Ns(r){return r.h||(r.h=r.i())}function ks(){}var ke={OPEN:"a",kb:"b",Ja:"c",wb:"d"};function dr(){lt.call(this,"d")}b(dr,lt);function mr(){lt.call(this,"c")}b(mr,lt);var Yt={},bs=null;function mn(){return bs=bs||new ct}Yt.La="serverreachability";function xs(r){lt.call(this,Yt.La,r)}b(xs,lt);function be(r){const a=mn();_t(a,new xs(a))}Yt.STAT_EVENT="statevent";function Os(r,a){lt.call(this,Yt.STAT_EVENT,r),this.stat=a}b(Os,lt);function yt(r){const a=mn();_t(a,new Os(a,r))}Yt.Ma="timingevent";function Ms(r,a){lt.call(this,Yt.Ma,r),this.size=a}b(Ms,lt);function xe(r,a){if(typeof r!="function")throw Error("Fn must not be null and must be a function");return l.setTimeout(function(){r()},a)}function Oe(){this.g=!0}Oe.prototype.xa=function(){this.g=!1};function ja(r,a,h,c,v,A){r.info(function(){if(r.g)if(A)for(var V="",z=A.split("&"),at=0;at<z.length;at++){var B=z[at].split("=");if(1<B.length){var ft=B[0];B=B[1];var dt=ft.split("_");V=2<=dt.length&&dt[1]=="type"?V+(ft+"="+B+"&"):V+(ft+"=redacted&")}}else V=null;else V=A;return"XMLHTTP REQ ("+c+") [attempt "+v+"]: "+a+`
`+h+`
`+V})}function Ba(r,a,h,c,v,A,V){r.info(function(){return"XMLHTTP RESP ("+c+") [ attempt "+v+"]: "+a+`
`+h+`
`+A+" "+V})}function ae(r,a,h,c){r.info(function(){return"XMLHTTP TEXT ("+a+"): "+Ga(r,h)+(c?" "+c:"")})}function za(r,a){r.info(function(){return"TIMEOUT: "+a})}Oe.prototype.info=function(){};function Ga(r,a){if(!r.g)return a;if(!a)return null;try{var h=JSON.parse(a);if(h){for(r=0;r<h.length;r++)if(Array.isArray(h[r])){var c=h[r];if(!(2>c.length)){var v=c[1];if(Array.isArray(v)&&!(1>v.length)){var A=v[0];if(A!="noop"&&A!="stop"&&A!="close")for(var V=1;V<v.length;V++)v[V]=""}}}}return cr(h)}catch{return a}}var gn={NO_ERROR:0,gb:1,tb:2,sb:3,nb:4,rb:5,ub:6,Ia:7,TIMEOUT:8,xb:9},Ls={lb:"complete",Hb:"success",Ja:"error",Ia:"abort",zb:"ready",Ab:"readystatechange",TIMEOUT:"timeout",vb:"incrementaldata",yb:"progress",ob:"downloadprogress",Pb:"uploadprogress"},gr;function pn(){}b(pn,fr),pn.prototype.g=function(){return new XMLHttpRequest},pn.prototype.i=function(){return{}},gr=new pn;function Lt(r,a,h,c){this.j=r,this.i=a,this.l=h,this.R=c||1,this.U=new Ne(this),this.I=45e3,this.H=null,this.o=!1,this.m=this.A=this.v=this.L=this.F=this.S=this.B=null,this.D=[],this.g=null,this.C=0,this.s=this.u=null,this.X=-1,this.J=!1,this.O=0,this.M=null,this.W=this.K=this.T=this.P=!1,this.h=new Fs}function Fs(){this.i=null,this.g="",this.h=!1}var Us={},pr={};function _r(r,a,h){r.L=1,r.v=Tn(kt(a)),r.m=h,r.P=!0,qs(r,null)}function qs(r,a){r.F=Date.now(),_n(r),r.A=kt(r.v);var h=r.A,c=r.R;Array.isArray(c)||(c=[String(c)]),ti(h.i,"t",c),r.C=0,h=r.j.J,r.h=new Fs,r.g=yi(r.j,h?a:null,!r.m),0<r.O&&(r.M=new Fa(P(r.Y,r,r.g),r.O)),a=r.U,h=r.g,c=r.ca;var v="readystatechange";Array.isArray(v)||(v&&(Cs[0]=v.toString()),v=Cs);for(var A=0;A<v.length;A++){var V=As(h,v[A],c||a.handleEvent,!1,a.h||a);if(!V)break;a.g[V.key]=V}a=r.H?m(r.H):{},r.m?(r.u||(r.u="POST"),a["Content-Type"]="application/x-www-form-urlencoded",r.g.ea(r.A,r.u,r.m,a)):(r.u="GET",r.g.ea(r.A,r.u,null,a)),be(),ja(r.i,r.u,r.A,r.l,r.R,r.m)}Lt.prototype.ca=function(r){r=r.target;const a=this.M;a&&bt(r)==3?a.j():this.Y(r)},Lt.prototype.Y=function(r){try{if(r==this.g)t:{const dt=bt(this.g);var a=this.g.Ba();const le=this.g.Z();if(!(3>dt)&&(dt!=3||this.g&&(this.h.h||this.g.oa()||ai(this.g)))){this.J||dt!=4||a==7||(a==8||0>=le?be(3):be(2)),yr(this);var h=this.g.Z();this.X=h;e:if(js(this)){var c=ai(this.g);r="";var v=c.length,A=bt(this.g)==4;if(!this.h.i){if(typeof TextDecoder>"u"){Jt(this),Me(this);var V="";break e}this.h.i=new l.TextDecoder}for(a=0;a<v;a++)this.h.h=!0,r+=this.h.i.decode(c[a],{stream:!(A&&a==v-1)});c.length=0,this.h.g+=r,this.C=0,V=this.h.g}else V=this.g.oa();if(this.o=h==200,Ba(this.i,this.u,this.A,this.l,this.R,dt,h),this.o){if(this.T&&!this.K){e:{if(this.g){var z,at=this.g;if((z=at.g?at.g.getResponseHeader("X-HTTP-Initial-Response"):null)&&!G(z)){var B=z;break e}}B=null}if(h=B)ae(this.i,this.l,h,"Initial handshake response via X-HTTP-Initial-Response"),this.K=!0,Er(this,h);else{this.o=!1,this.s=3,yt(12),Jt(this),Me(this);break t}}if(this.P){h=!0;let At;for(;!this.J&&this.C<V.length;)if(At=Ka(this,V),At==pr){dt==4&&(this.s=4,yt(14),h=!1),ae(this.i,this.l,null,"[Incomplete Response]");break}else if(At==Us){this.s=4,yt(15),ae(this.i,this.l,V,"[Invalid Chunk]"),h=!1;break}else ae(this.i,this.l,At,null),Er(this,At);if(js(this)&&this.C!=0&&(this.h.g=this.h.g.slice(this.C),this.C=0),dt!=4||V.length!=0||this.h.h||(this.s=1,yt(16),h=!1),this.o=this.o&&h,!h)ae(this.i,this.l,V,"[Invalid Chunked Response]"),Jt(this),Me(this);else if(0<V.length&&!this.W){this.W=!0;var ft=this.j;ft.g==this&&ft.ba&&!ft.M&&(ft.j.info("Great, no buffering proxy detected. Bytes received: "+V.length),Rr(ft),ft.M=!0,yt(11))}}else ae(this.i,this.l,V,null),Er(this,V);dt==4&&Jt(this),this.o&&!this.J&&(dt==4?mi(this.j,this):(this.o=!1,_n(this)))}else uu(this.g),h==400&&0<V.indexOf("Unknown SID")?(this.s=3,yt(12)):(this.s=0,yt(13)),Jt(this),Me(this)}}}catch{}finally{}};function js(r){return r.g?r.u=="GET"&&r.L!=2&&r.j.Ca:!1}function Ka(r,a){var h=r.C,c=a.indexOf(`
`,h);return c==-1?pr:(h=Number(a.substring(h,c)),isNaN(h)?Us:(c+=1,c+h>a.length?pr:(a=a.slice(c,c+h),r.C=c+h,a)))}Lt.prototype.cancel=function(){this.J=!0,Jt(this)};function _n(r){r.S=Date.now()+r.I,Bs(r,r.I)}function Bs(r,a){if(r.B!=null)throw Error("WatchDog timer not null");r.B=xe(P(r.ba,r),a)}function yr(r){r.B&&(l.clearTimeout(r.B),r.B=null)}Lt.prototype.ba=function(){this.B=null;const r=Date.now();0<=r-this.S?(za(this.i,this.A),this.L!=2&&(be(),yt(17)),Jt(this),this.s=2,Me(this)):Bs(this,this.S-r)};function Me(r){r.j.G==0||r.J||mi(r.j,r)}function Jt(r){yr(r);var a=r.M;a&&typeof a.ma=="function"&&a.ma(),r.M=null,Ds(r.U),r.g&&(a=r.g,r.g=null,a.abort(),a.ma())}function Er(r,a){try{var h=r.j;if(h.G!=0&&(h.g==r||Tr(h.h,r))){if(!r.K&&Tr(h.h,r)&&h.G==3){try{var c=h.Da.g.parse(a)}catch{c=null}if(Array.isArray(c)&&c.length==3){var v=c;if(v[0]==0){t:if(!h.u){if(h.g)if(h.g.F+3e3<r.F)Pn(h),wn(h);else break t;wr(h),yt(18)}}else h.za=v[1],0<h.za-h.T&&37500>v[2]&&h.F&&h.v==0&&!h.C&&(h.C=xe(P(h.Za,h),6e3));if(1>=Ks(h.h)&&h.ca){try{h.ca()}catch{}h.ca=void 0}}else te(h,11)}else if((r.K||h.g==r)&&Pn(h),!G(a))for(v=h.Da.g.parse(a),a=0;a<v.length;a++){let B=v[a];if(h.T=B[0],B=B[1],h.G==2)if(B[0]=="c"){h.K=B[1],h.ia=B[2];const ft=B[3];ft!=null&&(h.la=ft,h.j.info("VER="+h.la));const dt=B[4];dt!=null&&(h.Aa=dt,h.j.info("SVER="+h.Aa));const le=B[5];le!=null&&typeof le=="number"&&0<le&&(c=1.5*le,h.L=c,h.j.info("backChannelRequestTimeoutMs_="+c)),c=h;const At=r.g;if(At){const Vn=At.g?At.g.getResponseHeader("X-Client-Wire-Protocol"):null;if(Vn){var A=c.h;A.g||Vn.indexOf("spdy")==-1&&Vn.indexOf("quic")==-1&&Vn.indexOf("h2")==-1||(A.j=A.l,A.g=new Set,A.h&&(vr(A,A.h),A.h=null))}if(c.D){const Pr=At.g?At.g.getResponseHeader("X-HTTP-Session-Id"):null;Pr&&(c.ya=Pr,$(c.I,c.D,Pr))}}h.G=3,h.l&&h.l.ua(),h.ba&&(h.R=Date.now()-r.F,h.j.info("Handshake RTT: "+h.R+"ms")),c=h;var V=r;if(c.qa=_i(c,c.J?c.ia:null,c.W),V.K){$s(c.h,V);var z=V,at=c.L;at&&(z.I=at),z.B&&(yr(z),_n(z)),c.g=V}else fi(c);0<h.i.length&&Rn(h)}else B[0]!="stop"&&B[0]!="close"||te(h,7);else h.G==3&&(B[0]=="stop"||B[0]=="close"?B[0]=="stop"?te(h,7):Ar(h):B[0]!="noop"&&h.l&&h.l.ta(B),h.v=0)}}be(4)}catch{}}var $a=class{constructor(r,a){this.g=r,this.map=a}};function zs(r){this.l=r||10,l.PerformanceNavigationTiming?(r=l.performance.getEntriesByType("navigation"),r=0<r.length&&(r[0].nextHopProtocol=="hq"||r[0].nextHopProtocol=="h2")):r=!!(l.chrome&&l.chrome.loadTimes&&l.chrome.loadTimes()&&l.chrome.loadTimes().wasFetchedViaSpdy),this.j=r?this.l:1,this.g=null,1<this.j&&(this.g=new Set),this.h=null,this.i=[]}function Gs(r){return r.h?!0:r.g?r.g.size>=r.j:!1}function Ks(r){return r.h?1:r.g?r.g.size:0}function Tr(r,a){return r.h?r.h==a:r.g?r.g.has(a):!1}function vr(r,a){r.g?r.g.add(a):r.h=a}function $s(r,a){r.h&&r.h==a?r.h=null:r.g&&r.g.has(a)&&r.g.delete(a)}zs.prototype.cancel=function(){if(this.i=Qs(this),this.h)this.h.cancel(),this.h=null;else if(this.g&&this.g.size!==0){for(const r of this.g.values())r.cancel();this.g.clear()}};function Qs(r){if(r.h!=null)return r.i.concat(r.h.D);if(r.g!=null&&r.g.size!==0){let a=r.i;for(const h of r.g.values())a=a.concat(h.D);return a}return M(r.i)}function Qa(r){if(r.V&&typeof r.V=="function")return r.V();if(typeof Map<"u"&&r instanceof Map||typeof Set<"u"&&r instanceof Set)return Array.from(r.values());if(typeof r=="string")return r.split("");if(f(r)){for(var a=[],h=r.length,c=0;c<h;c++)a.push(r[c]);return a}a=[],h=0;for(c in r)a[h++]=r[c];return a}function Ha(r){if(r.na&&typeof r.na=="function")return r.na();if(!r.V||typeof r.V!="function"){if(typeof Map<"u"&&r instanceof Map)return Array.from(r.keys());if(!(typeof Set<"u"&&r instanceof Set)){if(f(r)||typeof r=="string"){var a=[];r=r.length;for(var h=0;h<r;h++)a.push(h);return a}a=[],h=0;for(const c in r)a[h++]=c;return a}}}function Hs(r,a){if(r.forEach&&typeof r.forEach=="function")r.forEach(a,void 0);else if(f(r)||typeof r=="string")Array.prototype.forEach.call(r,a,void 0);else for(var h=Ha(r),c=Qa(r),v=c.length,A=0;A<v;A++)a.call(void 0,c[A],h&&h[A],r)}var Ws=RegExp("^(?:([^:/?#.]+):)?(?://(?:([^\\\\/?#]*)@)?([^\\\\/?#]*?)(?::([0-9]+))?(?=[\\\\/?#]|$))?([^?#]+)?(?:\\?([^#]*))?(?:#([\\s\\S]*))?$");function Wa(r,a){if(r){r=r.split("&");for(var h=0;h<r.length;h++){var c=r[h].indexOf("="),v=null;if(0<=c){var A=r[h].substring(0,c);v=r[h].substring(c+1)}else A=r[h];a(A,v?decodeURIComponent(v.replace(/\+/g," ")):"")}}}function Zt(r){if(this.g=this.o=this.j="",this.s=null,this.m=this.l="",this.h=!1,r instanceof Zt){this.h=r.h,yn(this,r.j),this.o=r.o,this.g=r.g,En(this,r.s),this.l=r.l;var a=r.i,h=new Ue;h.i=a.i,a.g&&(h.g=new Map(a.g),h.h=a.h),Xs(this,h),this.m=r.m}else r&&(a=String(r).match(Ws))?(this.h=!1,yn(this,a[1]||"",!0),this.o=Le(a[2]||""),this.g=Le(a[3]||"",!0),En(this,a[4]),this.l=Le(a[5]||"",!0),Xs(this,a[6]||"",!0),this.m=Le(a[7]||"")):(this.h=!1,this.i=new Ue(null,this.h))}Zt.prototype.toString=function(){var r=[],a=this.j;a&&r.push(Fe(a,Ys,!0),":");var h=this.g;return(h||a=="file")&&(r.push("//"),(a=this.o)&&r.push(Fe(a,Ys,!0),"@"),r.push(encodeURIComponent(String(h)).replace(/%25([0-9a-fA-F]{2})/g,"%$1")),h=this.s,h!=null&&r.push(":",String(h))),(h=this.l)&&(this.g&&h.charAt(0)!="/"&&r.push("/"),r.push(Fe(h,h.charAt(0)=="/"?Ja:Ya,!0))),(h=this.i.toString())&&r.push("?",h),(h=this.m)&&r.push("#",Fe(h,tu)),r.join("")};function kt(r){return new Zt(r)}function yn(r,a,h){r.j=h?Le(a,!0):a,r.j&&(r.j=r.j.replace(/:$/,""))}function En(r,a){if(a){if(a=Number(a),isNaN(a)||0>a)throw Error("Bad port number "+a);r.s=a}else r.s=null}function Xs(r,a,h){a instanceof Ue?(r.i=a,eu(r.i,r.h)):(h||(a=Fe(a,Za)),r.i=new Ue(a,r.h))}function $(r,a,h){r.i.set(a,h)}function Tn(r){return $(r,"zx",Math.floor(2147483648*Math.random()).toString(36)+Math.abs(Math.floor(2147483648*Math.random())^Date.now()).toString(36)),r}function Le(r,a){return r?a?decodeURI(r.replace(/%25/g,"%2525")):decodeURIComponent(r):""}function Fe(r,a,h){return typeof r=="string"?(r=encodeURI(r).replace(a,Xa),h&&(r=r.replace(/%25([0-9a-fA-F]{2})/g,"%$1")),r):null}function Xa(r){return r=r.charCodeAt(0),"%"+(r>>4&15).toString(16)+(r&15).toString(16)}var Ys=/[#\/\?@]/g,Ya=/[#\?:]/g,Ja=/[#\?]/g,Za=/[#\?@]/g,tu=/#/g;function Ue(r,a){this.h=this.g=null,this.i=r||null,this.j=!!a}function Ft(r){r.g||(r.g=new Map,r.h=0,r.i&&Wa(r.i,function(a,h){r.add(decodeURIComponent(a.replace(/\+/g," ")),h)}))}s=Ue.prototype,s.add=function(r,a){Ft(this),this.i=null,r=ue(this,r);var h=this.g.get(r);return h||this.g.set(r,h=[]),h.push(a),this.h+=1,this};function Js(r,a){Ft(r),a=ue(r,a),r.g.has(a)&&(r.i=null,r.h-=r.g.get(a).length,r.g.delete(a))}function Zs(r,a){return Ft(r),a=ue(r,a),r.g.has(a)}s.forEach=function(r,a){Ft(this),this.g.forEach(function(h,c){h.forEach(function(v){r.call(a,v,c,this)},this)},this)},s.na=function(){Ft(this);const r=Array.from(this.g.values()),a=Array.from(this.g.keys()),h=[];for(let c=0;c<a.length;c++){const v=r[c];for(let A=0;A<v.length;A++)h.push(a[c])}return h},s.V=function(r){Ft(this);let a=[];if(typeof r=="string")Zs(this,r)&&(a=a.concat(this.g.get(ue(this,r))));else{r=Array.from(this.g.values());for(let h=0;h<r.length;h++)a=a.concat(r[h])}return a},s.set=function(r,a){return Ft(this),this.i=null,r=ue(this,r),Zs(this,r)&&(this.h-=this.g.get(r).length),this.g.set(r,[a]),this.h+=1,this},s.get=function(r,a){return r?(r=this.V(r),0<r.length?String(r[0]):a):a};function ti(r,a,h){Js(r,a),0<h.length&&(r.i=null,r.g.set(ue(r,a),M(h)),r.h+=h.length)}s.toString=function(){if(this.i)return this.i;if(!this.g)return"";const r=[],a=Array.from(this.g.keys());for(var h=0;h<a.length;h++){var c=a[h];const A=encodeURIComponent(String(c)),V=this.V(c);for(c=0;c<V.length;c++){var v=A;V[c]!==""&&(v+="="+encodeURIComponent(String(V[c]))),r.push(v)}}return this.i=r.join("&")};function ue(r,a){return a=String(a),r.j&&(a=a.toLowerCase()),a}function eu(r,a){a&&!r.j&&(Ft(r),r.i=null,r.g.forEach(function(h,c){var v=c.toLowerCase();c!=v&&(Js(this,c),ti(this,v,h))},r)),r.j=a}function nu(r,a){const h=new Oe;if(l.Image){const c=new Image;c.onload=C(Ut,h,"TestLoadImage: loaded",!0,a,c),c.onerror=C(Ut,h,"TestLoadImage: error",!1,a,c),c.onabort=C(Ut,h,"TestLoadImage: abort",!1,a,c),c.ontimeout=C(Ut,h,"TestLoadImage: timeout",!1,a,c),l.setTimeout(function(){c.ontimeout&&c.ontimeout()},1e4),c.src=r}else a(!1)}function ru(r,a){const h=new Oe,c=new AbortController,v=setTimeout(()=>{c.abort(),Ut(h,"TestPingServer: timeout",!1,a)},1e4);fetch(r,{signal:c.signal}).then(A=>{clearTimeout(v),A.ok?Ut(h,"TestPingServer: ok",!0,a):Ut(h,"TestPingServer: server error",!1,a)}).catch(()=>{clearTimeout(v),Ut(h,"TestPingServer: error",!1,a)})}function Ut(r,a,h,c,v){try{v&&(v.onload=null,v.onerror=null,v.onabort=null,v.ontimeout=null),c(h)}catch{}}function su(){this.g=new qa}function iu(r,a,h){const c=h||"";try{Hs(r,function(v,A){let V=v;d(v)&&(V=cr(v)),a.push(c+A+"="+encodeURIComponent(V))})}catch(v){throw a.push(c+"type="+encodeURIComponent("_badmap")),v}}function vn(r){this.l=r.Ub||null,this.j=r.eb||!1}b(vn,fr),vn.prototype.g=function(){return new In(this.l,this.j)},vn.prototype.i=function(r){return function(){return r}}({});function In(r,a){ct.call(this),this.D=r,this.o=a,this.m=void 0,this.status=this.readyState=0,this.responseType=this.responseText=this.response=this.statusText="",this.onreadystatechange=null,this.u=new Headers,this.h=null,this.B="GET",this.A="",this.g=!1,this.v=this.j=this.l=null}b(In,ct),s=In.prototype,s.open=function(r,a){if(this.readyState!=0)throw this.abort(),Error("Error reopening a connection");this.B=r,this.A=a,this.readyState=1,je(this)},s.send=function(r){if(this.readyState!=1)throw this.abort(),Error("need to call open() first. ");this.g=!0;const a={headers:this.u,method:this.B,credentials:this.m,cache:void 0};r&&(a.body=r),(this.D||l).fetch(new Request(this.A,a)).then(this.Sa.bind(this),this.ga.bind(this))},s.abort=function(){this.response=this.responseText="",this.u=new Headers,this.status=0,this.j&&this.j.cancel("Request was aborted.").catch(()=>{}),1<=this.readyState&&this.g&&this.readyState!=4&&(this.g=!1,qe(this)),this.readyState=0},s.Sa=function(r){if(this.g&&(this.l=r,this.h||(this.status=this.l.status,this.statusText=this.l.statusText,this.h=r.headers,this.readyState=2,je(this)),this.g&&(this.readyState=3,je(this),this.g)))if(this.responseType==="arraybuffer")r.arrayBuffer().then(this.Qa.bind(this),this.ga.bind(this));else if(typeof l.ReadableStream<"u"&&"body"in r){if(this.j=r.body.getReader(),this.o){if(this.responseType)throw Error('responseType must be empty for "streamBinaryChunks" mode responses.');this.response=[]}else this.response=this.responseText="",this.v=new TextDecoder;ei(this)}else r.text().then(this.Ra.bind(this),this.ga.bind(this))};function ei(r){r.j.read().then(r.Pa.bind(r)).catch(r.ga.bind(r))}s.Pa=function(r){if(this.g){if(this.o&&r.value)this.response.push(r.value);else if(!this.o){var a=r.value?r.value:new Uint8Array(0);(a=this.v.decode(a,{stream:!r.done}))&&(this.response=this.responseText+=a)}r.done?qe(this):je(this),this.readyState==3&&ei(this)}},s.Ra=function(r){this.g&&(this.response=this.responseText=r,qe(this))},s.Qa=function(r){this.g&&(this.response=r,qe(this))},s.ga=function(){this.g&&qe(this)};function qe(r){r.readyState=4,r.l=null,r.j=null,r.v=null,je(r)}s.setRequestHeader=function(r,a){this.u.append(r,a)},s.getResponseHeader=function(r){return this.h&&this.h.get(r.toLowerCase())||""},s.getAllResponseHeaders=function(){if(!this.h)return"";const r=[],a=this.h.entries();for(var h=a.next();!h.done;)h=h.value,r.push(h[0]+": "+h[1]),h=a.next();return r.join(`\r
`)};function je(r){r.onreadystatechange&&r.onreadystatechange.call(r)}Object.defineProperty(In.prototype,"withCredentials",{get:function(){return this.m==="include"},set:function(r){this.m=r?"include":"same-origin"}});function ni(r){let a="";return ot(r,function(h,c){a+=c,a+=":",a+=h,a+=`\r
`}),a}function Ir(r,a,h){t:{for(c in h){var c=!1;break t}c=!0}c||(h=ni(h),typeof r=="string"?h!=null&&encodeURIComponent(String(h)):$(r,a,h))}function W(r){ct.call(this),this.headers=new Map,this.o=r||null,this.h=!1,this.v=this.g=null,this.D="",this.m=0,this.l="",this.j=this.B=this.u=this.A=!1,this.I=null,this.H="",this.J=!1}b(W,ct);var ou=/^https?$/i,au=["POST","PUT"];s=W.prototype,s.Ha=function(r){this.J=r},s.ea=function(r,a,h,c){if(this.g)throw Error("[goog.net.XhrIo] Object is active with another request="+this.D+"; newUri="+r);a=a?a.toUpperCase():"GET",this.D=r,this.l="",this.m=0,this.A=!1,this.h=!0,this.g=this.o?this.o.g():gr.g(),this.v=this.o?Ns(this.o):Ns(gr),this.g.onreadystatechange=P(this.Ea,this);try{this.B=!0,this.g.open(a,String(r),!0),this.B=!1}catch(A){ri(this,A);return}if(r=h||"",h=new Map(this.headers),c)if(Object.getPrototypeOf(c)===Object.prototype)for(var v in c)h.set(v,c[v]);else if(typeof c.keys=="function"&&typeof c.get=="function")for(const A of c.keys())h.set(A,c.get(A));else throw Error("Unknown input type for opt_headers: "+String(c));c=Array.from(h.keys()).find(A=>A.toLowerCase()=="content-type"),v=l.FormData&&r instanceof l.FormData,!(0<=Array.prototype.indexOf.call(au,a,void 0))||c||v||h.set("Content-Type","application/x-www-form-urlencoded;charset=utf-8");for(const[A,V]of h)this.g.setRequestHeader(A,V);this.H&&(this.g.responseType=this.H),"withCredentials"in this.g&&this.g.withCredentials!==this.J&&(this.g.withCredentials=this.J);try{oi(this),this.u=!0,this.g.send(r),this.u=!1}catch(A){ri(this,A)}};function ri(r,a){r.h=!1,r.g&&(r.j=!0,r.g.abort(),r.j=!1),r.l=a,r.m=5,si(r),An(r)}function si(r){r.A||(r.A=!0,_t(r,"complete"),_t(r,"error"))}s.abort=function(r){this.g&&this.h&&(this.h=!1,this.j=!0,this.g.abort(),this.j=!1,this.m=r||7,_t(this,"complete"),_t(this,"abort"),An(this))},s.N=function(){this.g&&(this.h&&(this.h=!1,this.j=!0,this.g.abort(),this.j=!1),An(this,!0)),W.aa.N.call(this)},s.Ea=function(){this.s||(this.B||this.u||this.j?ii(this):this.bb())},s.bb=function(){ii(this)};function ii(r){if(r.h&&typeof u<"u"&&(!r.v[1]||bt(r)!=4||r.Z()!=2)){if(r.u&&bt(r)==4)Ss(r.Ea,0,r);else if(_t(r,"readystatechange"),bt(r)==4){r.h=!1;try{const V=r.Z();t:switch(V){case 200:case 201:case 202:case 204:case 206:case 304:case 1223:var a=!0;break t;default:a=!1}var h;if(!(h=a)){var c;if(c=V===0){var v=String(r.D).match(Ws)[1]||null;!v&&l.self&&l.self.location&&(v=l.self.location.protocol.slice(0,-1)),c=!ou.test(v?v.toLowerCase():"")}h=c}if(h)_t(r,"complete"),_t(r,"success");else{r.m=6;try{var A=2<bt(r)?r.g.statusText:""}catch{A=""}r.l=A+" ["+r.Z()+"]",si(r)}}finally{An(r)}}}}function An(r,a){if(r.g){oi(r);const h=r.g,c=r.v[0]?()=>{}:null;r.g=null,r.v=null,a||_t(r,"ready");try{h.onreadystatechange=c}catch{}}}function oi(r){r.I&&(l.clearTimeout(r.I),r.I=null)}s.isActive=function(){return!!this.g};function bt(r){return r.g?r.g.readyState:0}s.Z=function(){try{return 2<bt(this)?this.g.status:-1}catch{return-1}},s.oa=function(){try{return this.g?this.g.responseText:""}catch{return""}},s.Oa=function(r){if(this.g){var a=this.g.responseText;return r&&a.indexOf(r)==0&&(a=a.substring(r.length)),Ua(a)}};function ai(r){try{if(!r.g)return null;if("response"in r.g)return r.g.response;switch(r.H){case"":case"text":return r.g.responseText;case"arraybuffer":if("mozResponseArrayBuffer"in r.g)return r.g.mozResponseArrayBuffer}return null}catch{return null}}function uu(r){const a={};r=(r.g&&2<=bt(r)&&r.g.getAllResponseHeaders()||"").split(`\r
`);for(let c=0;c<r.length;c++){if(G(r[c]))continue;var h=E(r[c]);const v=h[0];if(h=h[1],typeof h!="string")continue;h=h.trim();const A=a[v]||[];a[v]=A,A.push(h)}T(a,function(c){return c.join(", ")})}s.Ba=function(){return this.m},s.Ka=function(){return typeof this.l=="string"?this.l:String(this.l)};function Be(r,a,h){return h&&h.internalChannelParams&&h.internalChannelParams[r]||a}function ui(r){this.Aa=0,this.i=[],this.j=new Oe,this.ia=this.qa=this.I=this.W=this.g=this.ya=this.D=this.H=this.m=this.S=this.o=null,this.Ya=this.U=0,this.Va=Be("failFast",!1,r),this.F=this.C=this.u=this.s=this.l=null,this.X=!0,this.za=this.T=-1,this.Y=this.v=this.B=0,this.Ta=Be("baseRetryDelayMs",5e3,r),this.cb=Be("retryDelaySeedMs",1e4,r),this.Wa=Be("forwardChannelMaxRetries",2,r),this.wa=Be("forwardChannelRequestTimeoutMs",2e4,r),this.pa=r&&r.xmlHttpFactory||void 0,this.Xa=r&&r.Tb||void 0,this.Ca=r&&r.useFetchStreams||!1,this.L=void 0,this.J=r&&r.supportsCrossDomainXhr||!1,this.K="",this.h=new zs(r&&r.concurrentRequestLimit),this.Da=new su,this.P=r&&r.fastHandshake||!1,this.O=r&&r.encodeInitMessageHeaders||!1,this.P&&this.O&&(this.O=!1),this.Ua=r&&r.Rb||!1,r&&r.xa&&this.j.xa(),r&&r.forceLongPolling&&(this.X=!1),this.ba=!this.P&&this.X&&r&&r.detectBufferingProxy||!1,this.ja=void 0,r&&r.longPollingTimeout&&0<r.longPollingTimeout&&(this.ja=r.longPollingTimeout),this.ca=void 0,this.R=0,this.M=!1,this.ka=this.A=null}s=ui.prototype,s.la=8,s.G=1,s.connect=function(r,a,h,c){yt(0),this.W=r,this.H=a||{},h&&c!==void 0&&(this.H.OSID=h,this.H.OAID=c),this.F=this.X,this.I=_i(this,null,this.W),Rn(this)};function Ar(r){if(hi(r),r.G==3){var a=r.U++,h=kt(r.I);if($(h,"SID",r.K),$(h,"RID",a),$(h,"TYPE","terminate"),ze(r,h),a=new Lt(r,r.j,a),a.L=2,a.v=Tn(kt(h)),h=!1,l.navigator&&l.navigator.sendBeacon)try{h=l.navigator.sendBeacon(a.v.toString(),"")}catch{}!h&&l.Image&&(new Image().src=a.v,h=!0),h||(a.g=yi(a.j,null),a.g.ea(a.v)),a.F=Date.now(),_n(a)}pi(r)}function wn(r){r.g&&(Rr(r),r.g.cancel(),r.g=null)}function hi(r){wn(r),r.u&&(l.clearTimeout(r.u),r.u=null),Pn(r),r.h.cancel(),r.s&&(typeof r.s=="number"&&l.clearTimeout(r.s),r.s=null)}function Rn(r){if(!Gs(r.h)&&!r.s){r.s=!0;var a=r.Ga;Ve||Is(),Ce||(Ve(),Ce=!0),rr.add(a,r),r.B=0}}function hu(r,a){return Ks(r.h)>=r.h.j-(r.s?1:0)?!1:r.s?(r.i=a.D.concat(r.i),!0):r.G==1||r.G==2||r.B>=(r.Va?0:r.Wa)?!1:(r.s=xe(P(r.Ga,r,a),gi(r,r.B)),r.B++,!0)}s.Ga=function(r){if(this.s)if(this.s=null,this.G==1){if(!r){this.U=Math.floor(1e5*Math.random()),r=this.U++;const v=new Lt(this,this.j,r);let A=this.o;if(this.S&&(A?(A=m(A),y(A,this.S)):A=this.S),this.m!==null||this.O||(v.H=A,A=null),this.P)t:{for(var a=0,h=0;h<this.i.length;h++){e:{var c=this.i[h];if("__data__"in c.map&&(c=c.map.__data__,typeof c=="string")){c=c.length;break e}c=void 0}if(c===void 0)break;if(a+=c,4096<a){a=h;break t}if(a===4096||h===this.i.length-1){a=h+1;break t}}a=1e3}else a=1e3;a=ci(this,v,a),h=kt(this.I),$(h,"RID",r),$(h,"CVER",22),this.D&&$(h,"X-HTTP-Session-Id",this.D),ze(this,h),A&&(this.O?a="headers="+encodeURIComponent(String(ni(A)))+"&"+a:this.m&&Ir(h,this.m,A)),vr(this.h,v),this.Ua&&$(h,"TYPE","init"),this.P?($(h,"$req",a),$(h,"SID","null"),v.T=!0,_r(v,h,null)):_r(v,h,a),this.G=2}}else this.G==3&&(r?li(this,r):this.i.length==0||Gs(this.h)||li(this))};function li(r,a){var h;a?h=a.l:h=r.U++;const c=kt(r.I);$(c,"SID",r.K),$(c,"RID",h),$(c,"AID",r.T),ze(r,c),r.m&&r.o&&Ir(c,r.m,r.o),h=new Lt(r,r.j,h,r.B+1),r.m===null&&(h.H=r.o),a&&(r.i=a.D.concat(r.i)),a=ci(r,h,1e3),h.I=Math.round(.5*r.wa)+Math.round(.5*r.wa*Math.random()),vr(r.h,h),_r(h,c,a)}function ze(r,a){r.H&&ot(r.H,function(h,c){$(a,c,h)}),r.l&&Hs({},function(h,c){$(a,c,h)})}function ci(r,a,h){h=Math.min(r.i.length,h);var c=r.l?P(r.l.Na,r.l,r):null;t:{var v=r.i;let A=-1;for(;;){const V=["count="+h];A==-1?0<h?(A=v[0].g,V.push("ofs="+A)):A=0:V.push("ofs="+A);let z=!0;for(let at=0;at<h;at++){let B=v[at].g;const ft=v[at].map;if(B-=A,0>B)A=Math.max(0,v[at].g-100),z=!1;else try{iu(ft,V,"req"+B+"_")}catch{c&&c(ft)}}if(z){c=V.join("&");break t}}}return r=r.i.splice(0,h),a.D=r,c}function fi(r){if(!r.g&&!r.u){r.Y=1;var a=r.Fa;Ve||Is(),Ce||(Ve(),Ce=!0),rr.add(a,r),r.v=0}}function wr(r){return r.g||r.u||3<=r.v?!1:(r.Y++,r.u=xe(P(r.Fa,r),gi(r,r.v)),r.v++,!0)}s.Fa=function(){if(this.u=null,di(this),this.ba&&!(this.M||this.g==null||0>=this.R)){var r=2*this.R;this.j.info("BP detection timer enabled: "+r),this.A=xe(P(this.ab,this),r)}},s.ab=function(){this.A&&(this.A=null,this.j.info("BP detection timeout reached."),this.j.info("Buffering proxy detected and switch to long-polling!"),this.F=!1,this.M=!0,yt(10),wn(this),di(this))};function Rr(r){r.A!=null&&(l.clearTimeout(r.A),r.A=null)}function di(r){r.g=new Lt(r,r.j,"rpc",r.Y),r.m===null&&(r.g.H=r.o),r.g.O=0;var a=kt(r.qa);$(a,"RID","rpc"),$(a,"SID",r.K),$(a,"AID",r.T),$(a,"CI",r.F?"0":"1"),!r.F&&r.ja&&$(a,"TO",r.ja),$(a,"TYPE","xmlhttp"),ze(r,a),r.m&&r.o&&Ir(a,r.m,r.o),r.L&&(r.g.I=r.L);var h=r.g;r=r.ia,h.L=1,h.v=Tn(kt(a)),h.m=null,h.P=!0,qs(h,r)}s.Za=function(){this.C!=null&&(this.C=null,wn(this),wr(this),yt(19))};function Pn(r){r.C!=null&&(l.clearTimeout(r.C),r.C=null)}function mi(r,a){var h=null;if(r.g==a){Pn(r),Rr(r),r.g=null;var c=2}else if(Tr(r.h,a))h=a.D,$s(r.h,a),c=1;else return;if(r.G!=0){if(a.o)if(c==1){h=a.m?a.m.length:0,a=Date.now()-a.F;var v=r.B;c=mn(),_t(c,new Ms(c,h)),Rn(r)}else fi(r);else if(v=a.s,v==3||v==0&&0<a.X||!(c==1&&hu(r,a)||c==2&&wr(r)))switch(h&&0<h.length&&(a=r.h,a.i=a.i.concat(h)),v){case 1:te(r,5);break;case 4:te(r,10);break;case 3:te(r,6);break;default:te(r,2)}}}function gi(r,a){let h=r.Ta+Math.floor(Math.random()*r.cb);return r.isActive()||(h*=2),h*a}function te(r,a){if(r.j.info("Error code "+a),a==2){var h=P(r.fb,r),c=r.Xa;const v=!c;c=new Zt(c||"//www.google.com/images/cleardot.gif"),l.location&&l.location.protocol=="http"||yn(c,"https"),Tn(c),v?nu(c.toString(),h):ru(c.toString(),h)}else yt(2);r.G=0,r.l&&r.l.sa(a),pi(r),hi(r)}s.fb=function(r){r?(this.j.info("Successfully pinged google.com"),yt(2)):(this.j.info("Failed to ping google.com"),yt(1))};function pi(r){if(r.G=0,r.ka=[],r.l){const a=Qs(r.h);(a.length!=0||r.i.length!=0)&&(N(r.ka,a),N(r.ka,r.i),r.h.i.length=0,M(r.i),r.i.length=0),r.l.ra()}}function _i(r,a,h){var c=h instanceof Zt?kt(h):new Zt(h);if(c.g!="")a&&(c.g=a+"."+c.g),En(c,c.s);else{var v=l.location;c=v.protocol,a=a?a+"."+v.hostname:v.hostname,v=+v.port;var A=new Zt(null);c&&yn(A,c),a&&(A.g=a),v&&En(A,v),h&&(A.l=h),c=A}return h=r.D,a=r.ya,h&&a&&$(c,h,a),$(c,"VER",r.la),ze(r,c),c}function yi(r,a,h){if(a&&!r.J)throw Error("Can't create secondary domain capable XhrIo object.");return a=r.Ca&&!r.pa?new W(new vn({eb:h})):new W(r.pa),a.Ha(r.J),a}s.isActive=function(){return!!this.l&&this.l.isActive(this)};function Ei(){}s=Ei.prototype,s.ua=function(){},s.ta=function(){},s.sa=function(){},s.ra=function(){},s.isActive=function(){return!0},s.Na=function(){};function Sn(){}Sn.prototype.g=function(r,a){return new It(r,a)};function It(r,a){ct.call(this),this.g=new ui(a),this.l=r,this.h=a&&a.messageUrlParams||null,r=a&&a.messageHeaders||null,a&&a.clientProtocolHeaderRequired&&(r?r["X-Client-Protocol"]="webchannel":r={"X-Client-Protocol":"webchannel"}),this.g.o=r,r=a&&a.initMessageHeaders||null,a&&a.messageContentType&&(r?r["X-WebChannel-Content-Type"]=a.messageContentType:r={"X-WebChannel-Content-Type":a.messageContentType}),a&&a.va&&(r?r["X-WebChannel-Client-Profile"]=a.va:r={"X-WebChannel-Client-Profile":a.va}),this.g.S=r,(r=a&&a.Sb)&&!G(r)&&(this.g.m=r),this.v=a&&a.supportsCrossDomainXhr||!1,this.u=a&&a.sendRawJson||!1,(a=a&&a.httpSessionIdParam)&&!G(a)&&(this.g.D=a,r=this.h,r!==null&&a in r&&(r=this.h,a in r&&delete r[a])),this.j=new he(this)}b(It,ct),It.prototype.m=function(){this.g.l=this.j,this.v&&(this.g.J=!0),this.g.connect(this.l,this.h||void 0)},It.prototype.close=function(){Ar(this.g)},It.prototype.o=function(r){var a=this.g;if(typeof r=="string"){var h={};h.__data__=r,r=h}else this.u&&(h={},h.__data__=cr(r),r=h);a.i.push(new $a(a.Ya++,r)),a.G==3&&Rn(a)},It.prototype.N=function(){this.g.l=null,delete this.j,Ar(this.g),delete this.g,It.aa.N.call(this)};function Ti(r){dr.call(this),r.__headers__&&(this.headers=r.__headers__,this.statusCode=r.__status__,delete r.__headers__,delete r.__status__);var a=r.__sm__;if(a){t:{for(const h in a){r=h;break t}r=void 0}(this.i=r)&&(r=this.i,a=a!==null&&r in a?a[r]:void 0),this.data=a}else this.data=r}b(Ti,dr);function vi(){mr.call(this),this.status=1}b(vi,mr);function he(r){this.g=r}b(he,Ei),he.prototype.ua=function(){_t(this.g,"a")},he.prototype.ta=function(r){_t(this.g,new Ti(r))},he.prototype.sa=function(r){_t(this.g,new vi)},he.prototype.ra=function(){_t(this.g,"b")},Sn.prototype.createWebChannel=Sn.prototype.g,It.prototype.send=It.prototype.o,It.prototype.open=It.prototype.m,It.prototype.close=It.prototype.close,So=function(){return new Sn},Po=function(){return mn()},Ro=Yt,br={mb:0,pb:1,qb:2,Jb:3,Ob:4,Lb:5,Mb:6,Kb:7,Ib:8,Nb:9,PROXY:10,NOPROXY:11,Gb:12,Cb:13,Db:14,Bb:15,Eb:16,Fb:17,ib:18,hb:19,jb:20},gn.NO_ERROR=0,gn.TIMEOUT=8,gn.HTTP_ERROR=6,xn=gn,Ls.COMPLETE="complete",wo=Ls,ks.EventType=ke,ke.OPEN="a",ke.CLOSE="b",ke.ERROR="c",ke.MESSAGE="d",ct.prototype.listen=ct.prototype.K,Ge=ks,W.prototype.listenOnce=W.prototype.L,W.prototype.getLastError=W.prototype.Ka,W.prototype.getLastErrorCode=W.prototype.Ba,W.prototype.getStatus=W.prototype.Z,W.prototype.getResponseJson=W.prototype.Oa,W.prototype.getResponseText=W.prototype.oa,W.prototype.send=W.prototype.ea,W.prototype.setWithCredentials=W.prototype.Ha,Ao=W}).apply(typeof Cn<"u"?Cn:typeof self<"u"?self:typeof window<"u"?window:{});const wi="@firebase/firestore",Ri="4.9.0";/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class gt{constructor(t){this.uid=t}isAuthenticated(){return this.uid!=null}toKey(){return this.isAuthenticated()?"uid:"+this.uid:"anonymous-user"}isEqual(t){return t.uid===this.uid}}gt.UNAUTHENTICATED=new gt(null),gt.GOOGLE_CREDENTIALS=new gt("google-credentials-uid"),gt.FIRST_PARTY=new gt("first-party-uid"),gt.MOCK_USER=new gt("mock-user");/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */let we="12.0.0";/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const ie=new Eu("@firebase/firestore");function ce(){return ie.logLevel}function D(s,...t){if(ie.logLevel<=xt.DEBUG){const e=t.map(Jr);ie.debug(`Firestore (${we}): ${s}`,...e)}}function Ot(s,...t){if(ie.logLevel<=xt.ERROR){const e=t.map(Jr);ie.error(`Firestore (${we}): ${s}`,...e)}}function _e(s,...t){if(ie.logLevel<=xt.WARN){const e=t.map(Jr);ie.warn(`Firestore (${we}): ${s}`,...e)}}function Jr(s){if(typeof s=="string")return s;try{/**
* @license
* Copyright 2020 Google LLC
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/return function(e){return JSON.stringify(e)}(s)}catch{return s}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function L(s,t,e){let n="Unexpected state";typeof t=="string"?n=t:e=t,Vo(s,n,e)}function Vo(s,t,e){let n=`FIRESTORE (${we}) INTERNAL ASSERTION FAILED: ${t} (ID: ${s.toString(16)})`;if(e!==void 0)try{n+=" CONTEXT: "+JSON.stringify(e)}catch{n+=" CONTEXT: "+e}throw Ot(n),new Error(n)}function H(s,t,e,n){let i="Unexpected state";typeof e=="string"?i=e:n=e,s||Vo(t,i,n)}function q(s,t){return s}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const S={OK:"ok",CANCELLED:"cancelled",UNKNOWN:"unknown",INVALID_ARGUMENT:"invalid-argument",DEADLINE_EXCEEDED:"deadline-exceeded",NOT_FOUND:"not-found",ALREADY_EXISTS:"already-exists",PERMISSION_DENIED:"permission-denied",UNAUTHENTICATED:"unauthenticated",RESOURCE_EXHAUSTED:"resource-exhausted",FAILED_PRECONDITION:"failed-precondition",ABORTED:"aborted",OUT_OF_RANGE:"out-of-range",UNIMPLEMENTED:"unimplemented",INTERNAL:"internal",UNAVAILABLE:"unavailable",DATA_LOSS:"data-loss"};class k extends yu{constructor(t,e){super(t,e),this.code=t,this.message=e,this.toString=()=>`${this.name}: [code=${this.code}]: ${this.message}`}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ne{constructor(){this.promise=new Promise((t,e)=>{this.resolve=t,this.reject=e})}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Co{constructor(t,e){this.user=e,this.type="OAuth",this.headers=new Map,this.headers.set("Authorization",`Bearer ${t}`)}}class Pu{getToken(){return Promise.resolve(null)}invalidateToken(){}start(t,e){t.enqueueRetryable(()=>e(gt.UNAUTHENTICATED))}shutdown(){}}class Su{constructor(t){this.token=t,this.changeListener=null}getToken(){return Promise.resolve(this.token)}invalidateToken(){}start(t,e){this.changeListener=e,t.enqueueRetryable(()=>e(this.token.user))}shutdown(){this.changeListener=null}}class Vu{constructor(t){this.t=t,this.currentUser=gt.UNAUTHENTICATED,this.i=0,this.forceRefresh=!1,this.auth=null}start(t,e){H(this.o===void 0,42304);let n=this.i;const i=f=>this.i!==n?(n=this.i,e(f)):Promise.resolve();let o=new ne;this.o=()=>{this.i++,this.currentUser=this.u(),o.resolve(),o=new ne,t.enqueueRetryable(()=>i(this.currentUser))};const u=()=>{const f=o;t.enqueueRetryable(async()=>{await f.promise,await i(this.currentUser)})},l=f=>{D("FirebaseAuthCredentialsProvider","Auth detected"),this.auth=f,this.o&&(this.auth.addAuthTokenListener(this.o),u())};this.t.onInit(f=>l(f)),setTimeout(()=>{if(!this.auth){const f=this.t.getImmediate({optional:!0});f?l(f):(D("FirebaseAuthCredentialsProvider","Auth not yet detected"),o.resolve(),o=new ne)}},0),u()}getToken(){const t=this.i,e=this.forceRefresh;return this.forceRefresh=!1,this.auth?this.auth.getToken(e).then(n=>this.i!==t?(D("FirebaseAuthCredentialsProvider","getToken aborted due to token change."),this.getToken()):n?(H(typeof n.accessToken=="string",31837,{l:n}),new Co(n.accessToken,this.currentUser)):null):Promise.resolve(null)}invalidateToken(){this.forceRefresh=!0}shutdown(){this.auth&&this.o&&this.auth.removeAuthTokenListener(this.o),this.o=void 0}u(){const t=this.auth&&this.auth.getUid();return H(t===null||typeof t=="string",2055,{h:t}),new gt(t)}}class Cu{constructor(t,e,n){this.P=t,this.T=e,this.I=n,this.type="FirstParty",this.user=gt.FIRST_PARTY,this.A=new Map}R(){return this.I?this.I():null}get headers(){this.A.set("X-Goog-AuthUser",this.P);const t=this.R();return t&&this.A.set("Authorization",t),this.T&&this.A.set("X-Goog-Iam-Authorization-Token",this.T),this.A}}class Du{constructor(t,e,n){this.P=t,this.T=e,this.I=n}getToken(){return Promise.resolve(new Cu(this.P,this.T,this.I))}start(t,e){t.enqueueRetryable(()=>e(gt.FIRST_PARTY))}shutdown(){}invalidateToken(){}}class Pi{constructor(t){this.value=t,this.type="AppCheck",this.headers=new Map,t&&t.length>0&&this.headers.set("x-firebase-appcheck",this.value)}}class Nu{constructor(t,e){this.V=e,this.forceRefresh=!1,this.appCheck=null,this.m=null,this.p=null,Ru(t)&&t.settings.appCheckToken&&(this.p=t.settings.appCheckToken)}start(t,e){H(this.o===void 0,3512);const n=o=>{o.error!=null&&D("FirebaseAppCheckTokenProvider",`Error getting App Check token; using placeholder token instead. Error: ${o.error.message}`);const u=o.token!==this.m;return this.m=o.token,D("FirebaseAppCheckTokenProvider",`Received ${u?"new":"existing"} token.`),u?e(o.token):Promise.resolve()};this.o=o=>{t.enqueueRetryable(()=>n(o))};const i=o=>{D("FirebaseAppCheckTokenProvider","AppCheck detected"),this.appCheck=o,this.o&&this.appCheck.addTokenListener(this.o)};this.V.onInit(o=>i(o)),setTimeout(()=>{if(!this.appCheck){const o=this.V.getImmediate({optional:!0});o?i(o):D("FirebaseAppCheckTokenProvider","AppCheck not yet detected")}},0)}getToken(){if(this.p)return Promise.resolve(new Pi(this.p));const t=this.forceRefresh;return this.forceRefresh=!1,this.appCheck?this.appCheck.getToken(t).then(e=>e?(H(typeof e.token=="string",44558,{tokenResult:e}),this.m=e.token,new Pi(e.token)):null):Promise.resolve(null)}invalidateToken(){this.forceRefresh=!0}shutdown(){this.appCheck&&this.o&&this.appCheck.removeTokenListener(this.o),this.o=void 0}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function ku(s){const t=typeof self<"u"&&(self.crypto||self.msCrypto),e=new Uint8Array(s);if(t&&typeof t.getRandomValues=="function")t.getRandomValues(e);else for(let n=0;n<s;n++)e[n]=Math.floor(256*Math.random());return e}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Zr{static newId(){const t="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",e=62*Math.floor(4.129032258064516);let n="";for(;n.length<20;){const i=ku(40);for(let o=0;o<i.length;++o)n.length<20&&i[o]<e&&(n+=t.charAt(i[o]%62))}return n}}function F(s,t){return s<t?-1:s>t?1:0}function xr(s,t){const e=Math.min(s.length,t.length);for(let n=0;n<e;n++){const i=s.charAt(n),o=t.charAt(n);if(i!==o)return Sr(i)===Sr(o)?F(i,o):Sr(i)?1:-1}return F(s.length,t.length)}const bu=55296,xu=57343;function Sr(s){const t=s.charCodeAt(0);return t>=bu&&t<=xu}function ye(s,t,e){return s.length===t.length&&s.every((n,i)=>e(n,t[i]))}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Si="__name__";class wt{constructor(t,e,n){e===void 0?e=0:e>t.length&&L(637,{offset:e,range:t.length}),n===void 0?n=t.length-e:n>t.length-e&&L(1746,{length:n,range:t.length-e}),this.segments=t,this.offset=e,this.len=n}get length(){return this.len}isEqual(t){return wt.comparator(this,t)===0}child(t){const e=this.segments.slice(this.offset,this.limit());return t instanceof wt?t.forEach(n=>{e.push(n)}):e.push(t),this.construct(e)}limit(){return this.offset+this.length}popFirst(t){return t=t===void 0?1:t,this.construct(this.segments,this.offset+t,this.length-t)}popLast(){return this.construct(this.segments,this.offset,this.length-1)}firstSegment(){return this.segments[this.offset]}lastSegment(){return this.get(this.length-1)}get(t){return this.segments[this.offset+t]}isEmpty(){return this.length===0}isPrefixOf(t){if(t.length<this.length)return!1;for(let e=0;e<this.length;e++)if(this.get(e)!==t.get(e))return!1;return!0}isImmediateParentOf(t){if(this.length+1!==t.length)return!1;for(let e=0;e<this.length;e++)if(this.get(e)!==t.get(e))return!1;return!0}forEach(t){for(let e=this.offset,n=this.limit();e<n;e++)t(this.segments[e])}toArray(){return this.segments.slice(this.offset,this.limit())}static comparator(t,e){const n=Math.min(t.length,e.length);for(let i=0;i<n;i++){const o=wt.compareSegments(t.get(i),e.get(i));if(o!==0)return o}return F(t.length,e.length)}static compareSegments(t,e){const n=wt.isNumericId(t),i=wt.isNumericId(e);return n&&!i?-1:!n&&i?1:n&&i?wt.extractNumericId(t).compare(wt.extractNumericId(e)):xr(t,e)}static isNumericId(t){return t.startsWith("__id")&&t.endsWith("__")}static extractNumericId(t){return Bt.fromString(t.substring(4,t.length-2))}}class Q extends wt{construct(t,e,n){return new Q(t,e,n)}canonicalString(){return this.toArray().join("/")}toString(){return this.canonicalString()}toUriEncodedString(){return this.toArray().map(encodeURIComponent).join("/")}static fromString(...t){const e=[];for(const n of t){if(n.indexOf("//")>=0)throw new k(S.INVALID_ARGUMENT,`Invalid segment (${n}). Paths must not contain // in them.`);e.push(...n.split("/").filter(i=>i.length>0))}return new Q(e)}static emptyPath(){return new Q([])}}const Ou=/^[_a-zA-Z][_a-zA-Z0-9]*$/;class Et extends wt{construct(t,e,n){return new Et(t,e,n)}static isValidIdentifier(t){return Ou.test(t)}canonicalString(){return this.toArray().map(t=>(t=t.replace(/\\/g,"\\\\").replace(/`/g,"\\`"),Et.isValidIdentifier(t)||(t="`"+t+"`"),t)).join(".")}toString(){return this.canonicalString()}isKeyField(){return this.length===1&&this.get(0)===Si}static keyField(){return new Et([Si])}static fromServerFormat(t){const e=[];let n="",i=0;const o=()=>{if(n.length===0)throw new k(S.INVALID_ARGUMENT,`Invalid field path (${t}). Paths must not be empty, begin with '.', end with '.', or contain '..'`);e.push(n),n=""};let u=!1;for(;i<t.length;){const l=t[i];if(l==="\\"){if(i+1===t.length)throw new k(S.INVALID_ARGUMENT,"Path has trailing escape character: "+t);const f=t[i+1];if(f!=="\\"&&f!=="."&&f!=="`")throw new k(S.INVALID_ARGUMENT,"Path has invalid escape sequence: "+t);n+=f,i+=2}else l==="`"?(u=!u,i++):l!=="."||u?(n+=l,i++):(o(),i++)}if(o(),u)throw new k(S.INVALID_ARGUMENT,"Unterminated ` in path: "+t);return new Et(e)}static emptyPath(){return new Et([])}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class x{constructor(t){this.path=t}static fromPath(t){return new x(Q.fromString(t))}static fromName(t){return new x(Q.fromString(t).popFirst(5))}static empty(){return new x(Q.emptyPath())}get collectionGroup(){return this.path.popLast().lastSegment()}hasCollectionId(t){return this.path.length>=2&&this.path.get(this.path.length-2)===t}getCollectionGroup(){return this.path.get(this.path.length-2)}getCollectionPath(){return this.path.popLast()}isEqual(t){return t!==null&&Q.comparator(this.path,t.path)===0}toString(){return this.path.toString()}static comparator(t,e){return Q.comparator(t.path,e.path)}static isDocumentKey(t){return t.length%2==0}static fromSegments(t){return new x(new Q(t.slice()))}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function Mu(s,t,e){if(!e)throw new k(S.INVALID_ARGUMENT,`Function ${s}() cannot be called with an empty ${t}.`)}function Lu(s,t,e,n){if(t===!0&&n===!0)throw new k(S.INVALID_ARGUMENT,`${s} and ${e} cannot be used together.`)}function Vi(s){if(!x.isDocumentKey(s))throw new k(S.INVALID_ARGUMENT,`Invalid document reference. Document references must have an even number of segments, but ${s} has ${s.length}.`)}function Fu(s){return typeof s=="object"&&s!==null&&(Object.getPrototypeOf(s)===Object.prototype||Object.getPrototypeOf(s)===null)}function Uu(s){if(s===void 0)return"undefined";if(s===null)return"null";if(typeof s=="string")return s.length>20&&(s=`${s.substring(0,20)}...`),JSON.stringify(s);if(typeof s=="number"||typeof s=="boolean")return""+s;if(typeof s=="object"){if(s instanceof Array)return"an array";{const t=function(n){return n.constructor?n.constructor.name:null}(s);return t?`a custom ${t} object`:"an object"}}return typeof s=="function"?"a function":L(12329,{type:typeof s})}function Or(s,t){if("_delegate"in s&&(s=s._delegate),!(s instanceof t)){if(t.name===s.constructor.name)throw new k(S.INVALID_ARGUMENT,"Type does not match the expected instance. Did you pass a reference from a different Firestore SDK?");{const e=Uu(s);throw new k(S.INVALID_ARGUMENT,`Expected type '${t.name}', but it was: ${e}`)}}return s}/**
 * @license
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function tt(s,t){const e={typeString:s};return t&&(e.value=t),e}function sn(s,t){if(!Fu(s))throw new k(S.INVALID_ARGUMENT,"JSON must be an object");let e;for(const n in t)if(t[n]){const i=t[n].typeString,o="value"in t[n]?{value:t[n].value}:void 0;if(!(n in s)){e=`JSON missing required field: '${n}'`;break}const u=s[n];if(i&&typeof u!==i){e=`JSON field '${n}' must be a ${i}.`;break}if(o!==void 0&&u!==o.value){e=`Expected '${n}' field to equal '${o.value}'`;break}}if(e)throw new k(S.INVALID_ARGUMENT,e);return!0}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Ci=-62135596800,Di=1e6;class Z{static now(){return Z.fromMillis(Date.now())}static fromDate(t){return Z.fromMillis(t.getTime())}static fromMillis(t){const e=Math.floor(t/1e3),n=Math.floor((t-1e3*e)*Di);return new Z(e,n)}constructor(t,e){if(this.seconds=t,this.nanoseconds=e,e<0)throw new k(S.INVALID_ARGUMENT,"Timestamp nanoseconds out of range: "+e);if(e>=1e9)throw new k(S.INVALID_ARGUMENT,"Timestamp nanoseconds out of range: "+e);if(t<Ci)throw new k(S.INVALID_ARGUMENT,"Timestamp seconds out of range: "+t);if(t>=253402300800)throw new k(S.INVALID_ARGUMENT,"Timestamp seconds out of range: "+t)}toDate(){return new Date(this.toMillis())}toMillis(){return 1e3*this.seconds+this.nanoseconds/Di}_compareTo(t){return this.seconds===t.seconds?F(this.nanoseconds,t.nanoseconds):F(this.seconds,t.seconds)}isEqual(t){return t.seconds===this.seconds&&t.nanoseconds===this.nanoseconds}toString(){return"Timestamp(seconds="+this.seconds+", nanoseconds="+this.nanoseconds+")"}toJSON(){return{type:Z._jsonSchemaVersion,seconds:this.seconds,nanoseconds:this.nanoseconds}}static fromJSON(t){if(sn(t,Z._jsonSchema))return new Z(t.seconds,t.nanoseconds)}valueOf(){const t=this.seconds-Ci;return String(t).padStart(12,"0")+"."+String(this.nanoseconds).padStart(9,"0")}}Z._jsonSchemaVersion="firestore/timestamp/1.0",Z._jsonSchema={type:tt("string",Z._jsonSchemaVersion),seconds:tt("number"),nanoseconds:tt("number")};/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class O{static fromTimestamp(t){return new O(t)}static min(){return new O(new Z(0,0))}static max(){return new O(new Z(253402300799,999999999))}constructor(t){this.timestamp=t}compareTo(t){return this.timestamp._compareTo(t.timestamp)}isEqual(t){return this.timestamp.isEqual(t.timestamp)}toMicroseconds(){return 1e6*this.timestamp.seconds+this.timestamp.nanoseconds/1e3}toString(){return"SnapshotVersion("+this.timestamp.toString()+")"}toTimestamp(){return this.timestamp}}/**
 * @license
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Ze=-1;function qu(s,t){const e=s.toTimestamp().seconds,n=s.toTimestamp().nanoseconds+1,i=O.fromTimestamp(n===1e9?new Z(e+1,0):new Z(e,n));return new Kt(i,x.empty(),t)}function ju(s){return new Kt(s.readTime,s.key,Ze)}class Kt{constructor(t,e,n){this.readTime=t,this.documentKey=e,this.largestBatchId=n}static min(){return new Kt(O.min(),x.empty(),Ze)}static max(){return new Kt(O.max(),x.empty(),Ze)}}function Bu(s,t){let e=s.readTime.compareTo(t.readTime);return e!==0?e:(e=x.comparator(s.documentKey,t.documentKey),e!==0?e:F(s.largestBatchId,t.largestBatchId))}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const zu="The current tab is not in the required state to perform this operation. It might be necessary to refresh the browser tab.";class Gu{constructor(){this.onCommittedListeners=[]}addOnCommittedListener(t){this.onCommittedListeners.push(t)}raiseOnCommittedEvent(){this.onCommittedListeners.forEach(t=>t())}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */async function $n(s){if(s.code!==S.FAILED_PRECONDITION||s.message!==zu)throw s;D("LocalStore","Unexpectedly lost primary lease")}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class R{constructor(t){this.nextCallback=null,this.catchCallback=null,this.result=void 0,this.error=void 0,this.isDone=!1,this.callbackAttached=!1,t(e=>{this.isDone=!0,this.result=e,this.nextCallback&&this.nextCallback(e)},e=>{this.isDone=!0,this.error=e,this.catchCallback&&this.catchCallback(e)})}catch(t){return this.next(void 0,t)}next(t,e){return this.callbackAttached&&L(59440),this.callbackAttached=!0,this.isDone?this.error?this.wrapFailure(e,this.error):this.wrapSuccess(t,this.result):new R((n,i)=>{this.nextCallback=o=>{this.wrapSuccess(t,o).next(n,i)},this.catchCallback=o=>{this.wrapFailure(e,o).next(n,i)}})}toPromise(){return new Promise((t,e)=>{this.next(t,e)})}wrapUserFunction(t){try{const e=t();return e instanceof R?e:R.resolve(e)}catch(e){return R.reject(e)}}wrapSuccess(t,e){return t?this.wrapUserFunction(()=>t(e)):R.resolve(e)}wrapFailure(t,e){return t?this.wrapUserFunction(()=>t(e)):R.reject(e)}static resolve(t){return new R((e,n)=>{e(t)})}static reject(t){return new R((e,n)=>{n(t)})}static waitFor(t){return new R((e,n)=>{let i=0,o=0,u=!1;t.forEach(l=>{++i,l.next(()=>{++o,u&&o===i&&e()},f=>n(f))}),u=!0,o===i&&e()})}static or(t){let e=R.resolve(!1);for(const n of t)e=e.next(i=>i?R.resolve(i):n());return e}static forEach(t,e){const n=[];return t.forEach((i,o)=>{n.push(e.call(this,i,o))}),this.waitFor(n)}static mapArray(t,e){return new R((n,i)=>{const o=t.length,u=new Array(o);let l=0;for(let f=0;f<o;f++){const d=f;e(t[d]).next(_=>{u[d]=_,++l,l===o&&n(u)},_=>i(_))}})}static doWhile(t,e){return new R((n,i)=>{const o=()=>{t()===!0?e().next(()=>{o()},i):n()};o()})}}function Ku(s){const t=s.match(/Android ([\d.]+)/i),e=t?t[1].split(".").slice(0,2).join("."):"-1";return Number(e)}function Re(s){return s.name==="IndexedDbTransactionError"}/**
 * @license
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Qn{constructor(t,e){this.previousValue=t,e&&(e.sequenceNumberHandler=n=>this.ae(n),this.ue=n=>e.writeSequenceNumber(n))}ae(t){return this.previousValue=Math.max(t,this.previousValue),this.previousValue}next(){const t=++this.previousValue;return this.ue&&this.ue(t),t}}Qn.ce=-1;/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const $u=-1;function Hn(s){return s==null}function Mr(s){return s===0&&1/s==-1/0}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Do="";function Qu(s){let t="";for(let e=0;e<s.length;e++)t.length>0&&(t=Ni(t)),t=Hu(s.get(e),t);return Ni(t)}function Hu(s,t){let e=t;const n=s.length;for(let i=0;i<n;i++){const o=s.charAt(i);switch(o){case"\0":e+="";break;case Do:e+="";break;default:e+=o}}return e}function Ni(s){return s+Do+""}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function ki(s){let t=0;for(const e in s)Object.prototype.hasOwnProperty.call(s,e)&&t++;return t}function on(s,t){for(const e in s)Object.prototype.hasOwnProperty.call(s,e)&&t(e,s[e])}function Wu(s){for(const t in s)if(Object.prototype.hasOwnProperty.call(s,t))return!1;return!0}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Y{constructor(t,e){this.comparator=t,this.root=e||ut.EMPTY}insert(t,e){return new Y(this.comparator,this.root.insert(t,e,this.comparator).copy(null,null,ut.BLACK,null,null))}remove(t){return new Y(this.comparator,this.root.remove(t,this.comparator).copy(null,null,ut.BLACK,null,null))}get(t){let e=this.root;for(;!e.isEmpty();){const n=this.comparator(t,e.key);if(n===0)return e.value;n<0?e=e.left:n>0&&(e=e.right)}return null}indexOf(t){let e=0,n=this.root;for(;!n.isEmpty();){const i=this.comparator(t,n.key);if(i===0)return e+n.left.size;i<0?n=n.left:(e+=n.left.size+1,n=n.right)}return-1}isEmpty(){return this.root.isEmpty()}get size(){return this.root.size}minKey(){return this.root.minKey()}maxKey(){return this.root.maxKey()}inorderTraversal(t){return this.root.inorderTraversal(t)}forEach(t){this.inorderTraversal((e,n)=>(t(e,n),!1))}toString(){const t=[];return this.inorderTraversal((e,n)=>(t.push(`${e}:${n}`),!1)),`{${t.join(", ")}}`}reverseTraversal(t){return this.root.reverseTraversal(t)}getIterator(){return new Dn(this.root,null,this.comparator,!1)}getIteratorFrom(t){return new Dn(this.root,t,this.comparator,!1)}getReverseIterator(){return new Dn(this.root,null,this.comparator,!0)}getReverseIteratorFrom(t){return new Dn(this.root,t,this.comparator,!0)}}class Dn{constructor(t,e,n,i){this.isReverse=i,this.nodeStack=[];let o=1;for(;!t.isEmpty();)if(o=e?n(t.key,e):1,e&&i&&(o*=-1),o<0)t=this.isReverse?t.left:t.right;else{if(o===0){this.nodeStack.push(t);break}this.nodeStack.push(t),t=this.isReverse?t.right:t.left}}getNext(){let t=this.nodeStack.pop();const e={key:t.key,value:t.value};if(this.isReverse)for(t=t.left;!t.isEmpty();)this.nodeStack.push(t),t=t.right;else for(t=t.right;!t.isEmpty();)this.nodeStack.push(t),t=t.left;return e}hasNext(){return this.nodeStack.length>0}peek(){if(this.nodeStack.length===0)return null;const t=this.nodeStack[this.nodeStack.length-1];return{key:t.key,value:t.value}}}class ut{constructor(t,e,n,i,o){this.key=t,this.value=e,this.color=n??ut.RED,this.left=i??ut.EMPTY,this.right=o??ut.EMPTY,this.size=this.left.size+1+this.right.size}copy(t,e,n,i,o){return new ut(t??this.key,e??this.value,n??this.color,i??this.left,o??this.right)}isEmpty(){return!1}inorderTraversal(t){return this.left.inorderTraversal(t)||t(this.key,this.value)||this.right.inorderTraversal(t)}reverseTraversal(t){return this.right.reverseTraversal(t)||t(this.key,this.value)||this.left.reverseTraversal(t)}min(){return this.left.isEmpty()?this:this.left.min()}minKey(){return this.min().key}maxKey(){return this.right.isEmpty()?this.key:this.right.maxKey()}insert(t,e,n){let i=this;const o=n(t,i.key);return i=o<0?i.copy(null,null,null,i.left.insert(t,e,n),null):o===0?i.copy(null,e,null,null,null):i.copy(null,null,null,null,i.right.insert(t,e,n)),i.fixUp()}removeMin(){if(this.left.isEmpty())return ut.EMPTY;let t=this;return t.left.isRed()||t.left.left.isRed()||(t=t.moveRedLeft()),t=t.copy(null,null,null,t.left.removeMin(),null),t.fixUp()}remove(t,e){let n,i=this;if(e(t,i.key)<0)i.left.isEmpty()||i.left.isRed()||i.left.left.isRed()||(i=i.moveRedLeft()),i=i.copy(null,null,null,i.left.remove(t,e),null);else{if(i.left.isRed()&&(i=i.rotateRight()),i.right.isEmpty()||i.right.isRed()||i.right.left.isRed()||(i=i.moveRedRight()),e(t,i.key)===0){if(i.right.isEmpty())return ut.EMPTY;n=i.right.min(),i=i.copy(n.key,n.value,null,null,i.right.removeMin())}i=i.copy(null,null,null,null,i.right.remove(t,e))}return i.fixUp()}isRed(){return this.color}fixUp(){let t=this;return t.right.isRed()&&!t.left.isRed()&&(t=t.rotateLeft()),t.left.isRed()&&t.left.left.isRed()&&(t=t.rotateRight()),t.left.isRed()&&t.right.isRed()&&(t=t.colorFlip()),t}moveRedLeft(){let t=this.colorFlip();return t.right.left.isRed()&&(t=t.copy(null,null,null,null,t.right.rotateRight()),t=t.rotateLeft(),t=t.colorFlip()),t}moveRedRight(){let t=this.colorFlip();return t.left.left.isRed()&&(t=t.rotateRight(),t=t.colorFlip()),t}rotateLeft(){const t=this.copy(null,null,ut.RED,null,this.right.left);return this.right.copy(null,null,this.color,t,null)}rotateRight(){const t=this.copy(null,null,ut.RED,this.left.right,null);return this.left.copy(null,null,this.color,null,t)}colorFlip(){const t=this.left.copy(null,null,!this.left.color,null,null),e=this.right.copy(null,null,!this.right.color,null,null);return this.copy(null,null,!this.color,t,e)}checkMaxDepth(){const t=this.check();return Math.pow(2,t)<=this.size+1}check(){if(this.isRed()&&this.left.isRed())throw L(43730,{key:this.key,value:this.value});if(this.right.isRed())throw L(14113,{key:this.key,value:this.value});const t=this.left.check();if(t!==this.right.check())throw L(27949);return t+(this.isRed()?0:1)}}ut.EMPTY=null,ut.RED=!0,ut.BLACK=!1;ut.EMPTY=new class{constructor(){this.size=0}get key(){throw L(57766)}get value(){throw L(16141)}get color(){throw L(16727)}get left(){throw L(29726)}get right(){throw L(36894)}copy(t,e,n,i,o){return this}insert(t,e,n){return new ut(t,e)}remove(t,e){return this}isEmpty(){return!0}inorderTraversal(t){return!1}reverseTraversal(t){return!1}minKey(){return null}maxKey(){return null}isRed(){return!1}checkMaxDepth(){return!0}check(){return 0}};/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class rt{constructor(t){this.comparator=t,this.data=new Y(this.comparator)}has(t){return this.data.get(t)!==null}first(){return this.data.minKey()}last(){return this.data.maxKey()}get size(){return this.data.size}indexOf(t){return this.data.indexOf(t)}forEach(t){this.data.inorderTraversal((e,n)=>(t(e),!1))}forEachInRange(t,e){const n=this.data.getIteratorFrom(t[0]);for(;n.hasNext();){const i=n.getNext();if(this.comparator(i.key,t[1])>=0)return;e(i.key)}}forEachWhile(t,e){let n;for(n=e!==void 0?this.data.getIteratorFrom(e):this.data.getIterator();n.hasNext();)if(!t(n.getNext().key))return}firstAfterOrEqual(t){const e=this.data.getIteratorFrom(t);return e.hasNext()?e.getNext().key:null}getIterator(){return new bi(this.data.getIterator())}getIteratorFrom(t){return new bi(this.data.getIteratorFrom(t))}add(t){return this.copy(this.data.remove(t).insert(t,!0))}delete(t){return this.has(t)?this.copy(this.data.remove(t)):this}isEmpty(){return this.data.isEmpty()}unionWith(t){let e=this;return e.size<t.size&&(e=t,t=this),t.forEach(n=>{e=e.add(n)}),e}isEqual(t){if(!(t instanceof rt)||this.size!==t.size)return!1;const e=this.data.getIterator(),n=t.data.getIterator();for(;e.hasNext();){const i=e.getNext().key,o=n.getNext().key;if(this.comparator(i,o)!==0)return!1}return!0}toArray(){const t=[];return this.forEach(e=>{t.push(e)}),t}toString(){const t=[];return this.forEach(e=>t.push(e)),"SortedSet("+t.toString()+")"}copy(t){const e=new rt(this.comparator);return e.data=t,e}}class bi{constructor(t){this.iter=t}getNext(){return this.iter.getNext().key}hasNext(){return this.iter.hasNext()}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class qt{constructor(t){this.fields=t,t.sort(Et.comparator)}static empty(){return new qt([])}unionWith(t){let e=new rt(Et.comparator);for(const n of this.fields)e=e.add(n);for(const n of t)e=e.add(n);return new qt(e.toArray())}covers(t){for(const e of this.fields)if(e.isPrefixOf(t))return!0;return!1}isEqual(t){return ye(this.fields,t.fields,(e,n)=>e.isEqual(n))}}/**
 * @license
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class No extends Error{constructor(){super(...arguments),this.name="Base64DecodeError"}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ht{constructor(t){this.binaryString=t}static fromBase64String(t){const e=function(i){try{return atob(i)}catch(o){throw typeof DOMException<"u"&&o instanceof DOMException?new No("Invalid base64 string: "+o):o}}(t);return new ht(e)}static fromUint8Array(t){const e=function(i){let o="";for(let u=0;u<i.length;++u)o+=String.fromCharCode(i[u]);return o}(t);return new ht(e)}[Symbol.iterator](){let t=0;return{next:()=>t<this.binaryString.length?{value:this.binaryString.charCodeAt(t++),done:!1}:{value:void 0,done:!0}}}toBase64(){return function(e){return btoa(e)}(this.binaryString)}toUint8Array(){return function(e){const n=new Uint8Array(e.length);for(let i=0;i<e.length;i++)n[i]=e.charCodeAt(i);return n}(this.binaryString)}approximateByteSize(){return 2*this.binaryString.length}compareTo(t){return F(this.binaryString,t.binaryString)}isEqual(t){return this.binaryString===t.binaryString}}ht.EMPTY_BYTE_STRING=new ht("");const Xu=new RegExp(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.(\d+))?Z$/);function $t(s){if(H(!!s,39018),typeof s=="string"){let t=0;const e=Xu.exec(s);if(H(!!e,46558,{timestamp:s}),e[1]){let i=e[1];i=(i+"000000000").substr(0,9),t=Number(i)}const n=new Date(s);return{seconds:Math.floor(n.getTime()/1e3),nanos:t}}return{seconds:X(s.seconds),nanos:X(s.nanos)}}function X(s){return typeof s=="number"?s:typeof s=="string"?Number(s):0}function Qt(s){return typeof s=="string"?ht.fromBase64String(s):ht.fromUint8Array(s)}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const ko="server_timestamp",bo="__type__",xo="__previous_value__",Oo="__local_write_time__";function ts(s){var e,n;return((n=(((e=s==null?void 0:s.mapValue)==null?void 0:e.fields)||{})[bo])==null?void 0:n.stringValue)===ko}function Wn(s){const t=s.mapValue.fields[xo];return ts(t)?Wn(t):t}function tn(s){const t=$t(s.mapValue.fields[Oo].timestampValue);return new Z(t.seconds,t.nanos)}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Yu{constructor(t,e,n,i,o,u,l,f,d,_){this.databaseId=t,this.appId=e,this.persistenceKey=n,this.host=i,this.ssl=o,this.forceLongPolling=u,this.autoDetectLongPolling=l,this.longPollingOptions=f,this.useFetchStreams=d,this.isUsingEmulator=_}}const Un="(default)";class en{constructor(t,e){this.projectId=t,this.database=e||Un}static empty(){return new en("","")}get isDefaultDatabase(){return this.database===Un}isEqual(t){return t instanceof en&&t.projectId===this.projectId&&t.database===this.database}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Ju="__type__",Zu="__max__",Nn={mapValue:{}},th="__vector__",Lr="value";function Ht(s){return"nullValue"in s?0:"booleanValue"in s?1:"integerValue"in s||"doubleValue"in s?2:"timestampValue"in s?3:"stringValue"in s?5:"bytesValue"in s?6:"referenceValue"in s?7:"geoPointValue"in s?8:"arrayValue"in s?9:"mapValue"in s?ts(s)?4:nh(s)?9007199254740991:eh(s)?10:11:L(28295,{value:s})}function Vt(s,t){if(s===t)return!0;const e=Ht(s);if(e!==Ht(t))return!1;switch(e){case 0:case 9007199254740991:return!0;case 1:return s.booleanValue===t.booleanValue;case 4:return tn(s).isEqual(tn(t));case 3:return function(i,o){if(typeof i.timestampValue=="string"&&typeof o.timestampValue=="string"&&i.timestampValue.length===o.timestampValue.length)return i.timestampValue===o.timestampValue;const u=$t(i.timestampValue),l=$t(o.timestampValue);return u.seconds===l.seconds&&u.nanos===l.nanos}(s,t);case 5:return s.stringValue===t.stringValue;case 6:return function(i,o){return Qt(i.bytesValue).isEqual(Qt(o.bytesValue))}(s,t);case 7:return s.referenceValue===t.referenceValue;case 8:return function(i,o){return X(i.geoPointValue.latitude)===X(o.geoPointValue.latitude)&&X(i.geoPointValue.longitude)===X(o.geoPointValue.longitude)}(s,t);case 2:return function(i,o){if("integerValue"in i&&"integerValue"in o)return X(i.integerValue)===X(o.integerValue);if("doubleValue"in i&&"doubleValue"in o){const u=X(i.doubleValue),l=X(o.doubleValue);return u===l?Mr(u)===Mr(l):isNaN(u)&&isNaN(l)}return!1}(s,t);case 9:return ye(s.arrayValue.values||[],t.arrayValue.values||[],Vt);case 10:case 11:return function(i,o){const u=i.mapValue.fields||{},l=o.mapValue.fields||{};if(ki(u)!==ki(l))return!1;for(const f in u)if(u.hasOwnProperty(f)&&(l[f]===void 0||!Vt(u[f],l[f])))return!1;return!0}(s,t);default:return L(52216,{left:s})}}function nn(s,t){return(s.values||[]).find(e=>Vt(e,t))!==void 0}function Ee(s,t){if(s===t)return 0;const e=Ht(s),n=Ht(t);if(e!==n)return F(e,n);switch(e){case 0:case 9007199254740991:return 0;case 1:return F(s.booleanValue,t.booleanValue);case 2:return function(o,u){const l=X(o.integerValue||o.doubleValue),f=X(u.integerValue||u.doubleValue);return l<f?-1:l>f?1:l===f?0:isNaN(l)?isNaN(f)?0:-1:1}(s,t);case 3:return xi(s.timestampValue,t.timestampValue);case 4:return xi(tn(s),tn(t));case 5:return xr(s.stringValue,t.stringValue);case 6:return function(o,u){const l=Qt(o),f=Qt(u);return l.compareTo(f)}(s.bytesValue,t.bytesValue);case 7:return function(o,u){const l=o.split("/"),f=u.split("/");for(let d=0;d<l.length&&d<f.length;d++){const _=F(l[d],f[d]);if(_!==0)return _}return F(l.length,f.length)}(s.referenceValue,t.referenceValue);case 8:return function(o,u){const l=F(X(o.latitude),X(u.latitude));return l!==0?l:F(X(o.longitude),X(u.longitude))}(s.geoPointValue,t.geoPointValue);case 9:return Oi(s.arrayValue,t.arrayValue);case 10:return function(o,u){var P,C,b,M;const l=o.fields||{},f=u.fields||{},d=(P=l[Lr])==null?void 0:P.arrayValue,_=(C=f[Lr])==null?void 0:C.arrayValue,w=F(((b=d==null?void 0:d.values)==null?void 0:b.length)||0,((M=_==null?void 0:_.values)==null?void 0:M.length)||0);return w!==0?w:Oi(d,_)}(s.mapValue,t.mapValue);case 11:return function(o,u){if(o===Nn.mapValue&&u===Nn.mapValue)return 0;if(o===Nn.mapValue)return 1;if(u===Nn.mapValue)return-1;const l=o.fields||{},f=Object.keys(l),d=u.fields||{},_=Object.keys(d);f.sort(),_.sort();for(let w=0;w<f.length&&w<_.length;++w){const P=xr(f[w],_[w]);if(P!==0)return P;const C=Ee(l[f[w]],d[_[w]]);if(C!==0)return C}return F(f.length,_.length)}(s.mapValue,t.mapValue);default:throw L(23264,{he:e})}}function xi(s,t){if(typeof s=="string"&&typeof t=="string"&&s.length===t.length)return F(s,t);const e=$t(s),n=$t(t),i=F(e.seconds,n.seconds);return i!==0?i:F(e.nanos,n.nanos)}function Oi(s,t){const e=s.values||[],n=t.values||[];for(let i=0;i<e.length&&i<n.length;++i){const o=Ee(e[i],n[i]);if(o)return o}return F(e.length,n.length)}function Te(s){return Fr(s)}function Fr(s){return"nullValue"in s?"null":"booleanValue"in s?""+s.booleanValue:"integerValue"in s?""+s.integerValue:"doubleValue"in s?""+s.doubleValue:"timestampValue"in s?function(e){const n=$t(e);return`time(${n.seconds},${n.nanos})`}(s.timestampValue):"stringValue"in s?s.stringValue:"bytesValue"in s?function(e){return Qt(e).toBase64()}(s.bytesValue):"referenceValue"in s?function(e){return x.fromName(e).toString()}(s.referenceValue):"geoPointValue"in s?function(e){return`geo(${e.latitude},${e.longitude})`}(s.geoPointValue):"arrayValue"in s?function(e){let n="[",i=!0;for(const o of e.values||[])i?i=!1:n+=",",n+=Fr(o);return n+"]"}(s.arrayValue):"mapValue"in s?function(e){const n=Object.keys(e.fields||{}).sort();let i="{",o=!0;for(const u of n)o?o=!1:i+=",",i+=`${u}:${Fr(e.fields[u])}`;return i+"}"}(s.mapValue):L(61005,{value:s})}function On(s){switch(Ht(s)){case 0:case 1:return 4;case 2:return 8;case 3:case 8:return 16;case 4:const t=Wn(s);return t?16+On(t):16;case 5:return 2*s.stringValue.length;case 6:return Qt(s.bytesValue).approximateByteSize();case 7:return s.referenceValue.length;case 9:return function(n){return(n.values||[]).reduce((i,o)=>i+On(o),0)}(s.arrayValue);case 10:case 11:return function(n){let i=0;return on(n.fields,(o,u)=>{i+=o.length+On(u)}),i}(s.mapValue);default:throw L(13486,{value:s})}}function Ur(s){return!!s&&"integerValue"in s}function es(s){return!!s&&"arrayValue"in s}function Mi(s){return!!s&&"nullValue"in s}function Li(s){return!!s&&"doubleValue"in s&&isNaN(Number(s.doubleValue))}function Vr(s){return!!s&&"mapValue"in s}function eh(s){var e,n;return((n=(((e=s==null?void 0:s.mapValue)==null?void 0:e.fields)||{})[Ju])==null?void 0:n.stringValue)===th}function He(s){if(s.geoPointValue)return{geoPointValue:{...s.geoPointValue}};if(s.timestampValue&&typeof s.timestampValue=="object")return{timestampValue:{...s.timestampValue}};if(s.mapValue){const t={mapValue:{fields:{}}};return on(s.mapValue.fields,(e,n)=>t.mapValue.fields[e]=He(n)),t}if(s.arrayValue){const t={arrayValue:{values:[]}};for(let e=0;e<(s.arrayValue.values||[]).length;++e)t.arrayValue.values[e]=He(s.arrayValue.values[e]);return t}return{...s}}function nh(s){return(((s.mapValue||{}).fields||{}).__type__||{}).stringValue===Zu}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Rt{constructor(t){this.value=t}static empty(){return new Rt({mapValue:{}})}field(t){if(t.isEmpty())return this.value;{let e=this.value;for(let n=0;n<t.length-1;++n)if(e=(e.mapValue.fields||{})[t.get(n)],!Vr(e))return null;return e=(e.mapValue.fields||{})[t.lastSegment()],e||null}}set(t,e){this.getFieldsMap(t.popLast())[t.lastSegment()]=He(e)}setAll(t){let e=Et.emptyPath(),n={},i=[];t.forEach((u,l)=>{if(!e.isImmediateParentOf(l)){const f=this.getFieldsMap(e);this.applyChanges(f,n,i),n={},i=[],e=l.popLast()}u?n[l.lastSegment()]=He(u):i.push(l.lastSegment())});const o=this.getFieldsMap(e);this.applyChanges(o,n,i)}delete(t){const e=this.field(t.popLast());Vr(e)&&e.mapValue.fields&&delete e.mapValue.fields[t.lastSegment()]}isEqual(t){return Vt(this.value,t.value)}getFieldsMap(t){let e=this.value;e.mapValue.fields||(e.mapValue={fields:{}});for(let n=0;n<t.length;++n){let i=e.mapValue.fields[t.get(n)];Vr(i)&&i.mapValue.fields||(i={mapValue:{fields:{}}},e.mapValue.fields[t.get(n)]=i),e=i}return e.mapValue.fields}applyChanges(t,e,n){on(e,(i,o)=>t[i]=o);for(const i of n)delete t[i]}clone(){return new Rt(He(this.value))}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class pt{constructor(t,e,n,i,o,u,l){this.key=t,this.documentType=e,this.version=n,this.readTime=i,this.createTime=o,this.data=u,this.documentState=l}static newInvalidDocument(t){return new pt(t,0,O.min(),O.min(),O.min(),Rt.empty(),0)}static newFoundDocument(t,e,n,i){return new pt(t,1,e,O.min(),n,i,0)}static newNoDocument(t,e){return new pt(t,2,e,O.min(),O.min(),Rt.empty(),0)}static newUnknownDocument(t,e){return new pt(t,3,e,O.min(),O.min(),Rt.empty(),2)}convertToFoundDocument(t,e){return!this.createTime.isEqual(O.min())||this.documentType!==2&&this.documentType!==0||(this.createTime=t),this.version=t,this.documentType=1,this.data=e,this.documentState=0,this}convertToNoDocument(t){return this.version=t,this.documentType=2,this.data=Rt.empty(),this.documentState=0,this}convertToUnknownDocument(t){return this.version=t,this.documentType=3,this.data=Rt.empty(),this.documentState=2,this}setHasCommittedMutations(){return this.documentState=2,this}setHasLocalMutations(){return this.documentState=1,this.version=O.min(),this}setReadTime(t){return this.readTime=t,this}get hasLocalMutations(){return this.documentState===1}get hasCommittedMutations(){return this.documentState===2}get hasPendingWrites(){return this.hasLocalMutations||this.hasCommittedMutations}isValidDocument(){return this.documentType!==0}isFoundDocument(){return this.documentType===1}isNoDocument(){return this.documentType===2}isUnknownDocument(){return this.documentType===3}isEqual(t){return t instanceof pt&&this.key.isEqual(t.key)&&this.version.isEqual(t.version)&&this.documentType===t.documentType&&this.documentState===t.documentState&&this.data.isEqual(t.data)}mutableCopy(){return new pt(this.key,this.documentType,this.version,this.readTime,this.createTime,this.data.clone(),this.documentState)}toString(){return`Document(${this.key}, ${this.version}, ${JSON.stringify(this.data.value)}, {createTime: ${this.createTime}}), {documentType: ${this.documentType}}), {documentState: ${this.documentState}})`}}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class qn{constructor(t,e){this.position=t,this.inclusive=e}}function Fi(s,t,e){let n=0;for(let i=0;i<s.position.length;i++){const o=t[i],u=s.position[i];if(o.field.isKeyField()?n=x.comparator(x.fromName(u.referenceValue),e.key):n=Ee(u,e.data.field(o.field)),o.dir==="desc"&&(n*=-1),n!==0)break}return n}function Ui(s,t){if(s===null)return t===null;if(t===null||s.inclusive!==t.inclusive||s.position.length!==t.position.length)return!1;for(let e=0;e<s.position.length;e++)if(!Vt(s.position[e],t.position[e]))return!1;return!0}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class jn{constructor(t,e="asc"){this.field=t,this.dir=e}}function rh(s,t){return s.dir===t.dir&&s.field.isEqual(t.field)}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Mo{}class nt extends Mo{constructor(t,e,n){super(),this.field=t,this.op=e,this.value=n}static create(t,e,n){return t.isKeyField()?e==="in"||e==="not-in"?this.createKeyFieldInFilter(t,e,n):new ih(t,e,n):e==="array-contains"?new uh(t,n):e==="in"?new hh(t,n):e==="not-in"?new lh(t,n):e==="array-contains-any"?new ch(t,n):new nt(t,e,n)}static createKeyFieldInFilter(t,e,n){return e==="in"?new oh(t,n):new ah(t,n)}matches(t){const e=t.data.field(this.field);return this.op==="!="?e!==null&&e.nullValue===void 0&&this.matchesComparison(Ee(e,this.value)):e!==null&&Ht(this.value)===Ht(e)&&this.matchesComparison(Ee(e,this.value))}matchesComparison(t){switch(this.op){case"<":return t<0;case"<=":return t<=0;case"==":return t===0;case"!=":return t!==0;case">":return t>0;case">=":return t>=0;default:return L(47266,{operator:this.op})}}isInequality(){return["<","<=",">",">=","!=","not-in"].indexOf(this.op)>=0}getFlattenedFilters(){return[this]}getFilters(){return[this]}}class Ct extends Mo{constructor(t,e){super(),this.filters=t,this.op=e,this.Pe=null}static create(t,e){return new Ct(t,e)}matches(t){return Lo(this)?this.filters.find(e=>!e.matches(t))===void 0:this.filters.find(e=>e.matches(t))!==void 0}getFlattenedFilters(){return this.Pe!==null||(this.Pe=this.filters.reduce((t,e)=>t.concat(e.getFlattenedFilters()),[])),this.Pe}getFilters(){return Object.assign([],this.filters)}}function Lo(s){return s.op==="and"}function Fo(s){return sh(s)&&Lo(s)}function sh(s){for(const t of s.filters)if(t instanceof Ct)return!1;return!0}function qr(s){if(s instanceof nt)return s.field.canonicalString()+s.op.toString()+Te(s.value);if(Fo(s))return s.filters.map(t=>qr(t)).join(",");{const t=s.filters.map(e=>qr(e)).join(",");return`${s.op}(${t})`}}function Uo(s,t){return s instanceof nt?function(n,i){return i instanceof nt&&n.op===i.op&&n.field.isEqual(i.field)&&Vt(n.value,i.value)}(s,t):s instanceof Ct?function(n,i){return i instanceof Ct&&n.op===i.op&&n.filters.length===i.filters.length?n.filters.reduce((o,u,l)=>o&&Uo(u,i.filters[l]),!0):!1}(s,t):void L(19439)}function qo(s){return s instanceof nt?function(e){return`${e.field.canonicalString()} ${e.op} ${Te(e.value)}`}(s):s instanceof Ct?function(e){return e.op.toString()+" {"+e.getFilters().map(qo).join(" ,")+"}"}(s):"Filter"}class ih extends nt{constructor(t,e,n){super(t,e,n),this.key=x.fromName(n.referenceValue)}matches(t){const e=x.comparator(t.key,this.key);return this.matchesComparison(e)}}class oh extends nt{constructor(t,e){super(t,"in",e),this.keys=jo("in",e)}matches(t){return this.keys.some(e=>e.isEqual(t.key))}}class ah extends nt{constructor(t,e){super(t,"not-in",e),this.keys=jo("not-in",e)}matches(t){return!this.keys.some(e=>e.isEqual(t.key))}}function jo(s,t){var e;return(((e=t.arrayValue)==null?void 0:e.values)||[]).map(n=>x.fromName(n.referenceValue))}class uh extends nt{constructor(t,e){super(t,"array-contains",e)}matches(t){const e=t.data.field(this.field);return es(e)&&nn(e.arrayValue,this.value)}}class hh extends nt{constructor(t,e){super(t,"in",e)}matches(t){const e=t.data.field(this.field);return e!==null&&nn(this.value.arrayValue,e)}}class lh extends nt{constructor(t,e){super(t,"not-in",e)}matches(t){if(nn(this.value.arrayValue,{nullValue:"NULL_VALUE"}))return!1;const e=t.data.field(this.field);return e!==null&&e.nullValue===void 0&&!nn(this.value.arrayValue,e)}}class ch extends nt{constructor(t,e){super(t,"array-contains-any",e)}matches(t){const e=t.data.field(this.field);return!(!es(e)||!e.arrayValue.values)&&e.arrayValue.values.some(n=>nn(this.value.arrayValue,n))}}/**
 * @license
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class fh{constructor(t,e=null,n=[],i=[],o=null,u=null,l=null){this.path=t,this.collectionGroup=e,this.orderBy=n,this.filters=i,this.limit=o,this.startAt=u,this.endAt=l,this.Te=null}}function qi(s,t=null,e=[],n=[],i=null,o=null,u=null){return new fh(s,t,e,n,i,o,u)}function ns(s){const t=q(s);if(t.Te===null){let e=t.path.canonicalString();t.collectionGroup!==null&&(e+="|cg:"+t.collectionGroup),e+="|f:",e+=t.filters.map(n=>qr(n)).join(","),e+="|ob:",e+=t.orderBy.map(n=>function(o){return o.field.canonicalString()+o.dir}(n)).join(","),Hn(t.limit)||(e+="|l:",e+=t.limit),t.startAt&&(e+="|lb:",e+=t.startAt.inclusive?"b:":"a:",e+=t.startAt.position.map(n=>Te(n)).join(",")),t.endAt&&(e+="|ub:",e+=t.endAt.inclusive?"a:":"b:",e+=t.endAt.position.map(n=>Te(n)).join(",")),t.Te=e}return t.Te}function rs(s,t){if(s.limit!==t.limit||s.orderBy.length!==t.orderBy.length)return!1;for(let e=0;e<s.orderBy.length;e++)if(!rh(s.orderBy[e],t.orderBy[e]))return!1;if(s.filters.length!==t.filters.length)return!1;for(let e=0;e<s.filters.length;e++)if(!Uo(s.filters[e],t.filters[e]))return!1;return s.collectionGroup===t.collectionGroup&&!!s.path.isEqual(t.path)&&!!Ui(s.startAt,t.startAt)&&Ui(s.endAt,t.endAt)}function jr(s){return x.isDocumentKey(s.path)&&s.collectionGroup===null&&s.filters.length===0}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Xn{constructor(t,e=null,n=[],i=[],o=null,u="F",l=null,f=null){this.path=t,this.collectionGroup=e,this.explicitOrderBy=n,this.filters=i,this.limit=o,this.limitType=u,this.startAt=l,this.endAt=f,this.Ie=null,this.Ee=null,this.de=null,this.startAt,this.endAt}}function dh(s,t,e,n,i,o,u,l){return new Xn(s,t,e,n,i,o,u,l)}function ss(s){return new Xn(s)}function ji(s){return s.filters.length===0&&s.limit===null&&s.startAt==null&&s.endAt==null&&(s.explicitOrderBy.length===0||s.explicitOrderBy.length===1&&s.explicitOrderBy[0].field.isKeyField())}function mh(s){return s.collectionGroup!==null}function We(s){const t=q(s);if(t.Ie===null){t.Ie=[];const e=new Set;for(const o of t.explicitOrderBy)t.Ie.push(o),e.add(o.field.canonicalString());const n=t.explicitOrderBy.length>0?t.explicitOrderBy[t.explicitOrderBy.length-1].dir:"asc";(function(u){let l=new rt(Et.comparator);return u.filters.forEach(f=>{f.getFlattenedFilters().forEach(d=>{d.isInequality()&&(l=l.add(d.field))})}),l})(t).forEach(o=>{e.has(o.canonicalString())||o.isKeyField()||t.Ie.push(new jn(o,n))}),e.has(Et.keyField().canonicalString())||t.Ie.push(new jn(Et.keyField(),n))}return t.Ie}function St(s){const t=q(s);return t.Ee||(t.Ee=gh(t,We(s))),t.Ee}function gh(s,t){if(s.limitType==="F")return qi(s.path,s.collectionGroup,t,s.filters,s.limit,s.startAt,s.endAt);{t=t.map(i=>{const o=i.dir==="desc"?"asc":"desc";return new jn(i.field,o)});const e=s.endAt?new qn(s.endAt.position,s.endAt.inclusive):null,n=s.startAt?new qn(s.startAt.position,s.startAt.inclusive):null;return qi(s.path,s.collectionGroup,t,s.filters,s.limit,e,n)}}function Br(s,t,e){return new Xn(s.path,s.collectionGroup,s.explicitOrderBy.slice(),s.filters.slice(),t,e,s.startAt,s.endAt)}function Yn(s,t){return rs(St(s),St(t))&&s.limitType===t.limitType}function Bo(s){return`${ns(St(s))}|lt:${s.limitType}`}function fe(s){return`Query(target=${function(e){let n=e.path.canonicalString();return e.collectionGroup!==null&&(n+=" collectionGroup="+e.collectionGroup),e.filters.length>0&&(n+=`, filters: [${e.filters.map(i=>qo(i)).join(", ")}]`),Hn(e.limit)||(n+=", limit: "+e.limit),e.orderBy.length>0&&(n+=`, orderBy: [${e.orderBy.map(i=>function(u){return`${u.field.canonicalString()} (${u.dir})`}(i)).join(", ")}]`),e.startAt&&(n+=", startAt: ",n+=e.startAt.inclusive?"b:":"a:",n+=e.startAt.position.map(i=>Te(i)).join(",")),e.endAt&&(n+=", endAt: ",n+=e.endAt.inclusive?"a:":"b:",n+=e.endAt.position.map(i=>Te(i)).join(",")),`Target(${n})`}(St(s))}; limitType=${s.limitType})`}function Jn(s,t){return t.isFoundDocument()&&function(n,i){const o=i.key.path;return n.collectionGroup!==null?i.key.hasCollectionId(n.collectionGroup)&&n.path.isPrefixOf(o):x.isDocumentKey(n.path)?n.path.isEqual(o):n.path.isImmediateParentOf(o)}(s,t)&&function(n,i){for(const o of We(n))if(!o.field.isKeyField()&&i.data.field(o.field)===null)return!1;return!0}(s,t)&&function(n,i){for(const o of n.filters)if(!o.matches(i))return!1;return!0}(s,t)&&function(n,i){return!(n.startAt&&!function(u,l,f){const d=Fi(u,l,f);return u.inclusive?d<=0:d<0}(n.startAt,We(n),i)||n.endAt&&!function(u,l,f){const d=Fi(u,l,f);return u.inclusive?d>=0:d>0}(n.endAt,We(n),i))}(s,t)}function ph(s){return s.collectionGroup||(s.path.length%2==1?s.path.lastSegment():s.path.get(s.path.length-2))}function zo(s){return(t,e)=>{let n=!1;for(const i of We(s)){const o=_h(i,t,e);if(o!==0)return o;n=n||i.field.isKeyField()}return 0}}function _h(s,t,e){const n=s.field.isKeyField()?x.comparator(t.key,e.key):function(o,u,l){const f=u.data.field(o),d=l.data.field(o);return f!==null&&d!==null?Ee(f,d):L(42886)}(s.field,t,e);switch(s.dir){case"asc":return n;case"desc":return-1*n;default:return L(19790,{direction:s.dir})}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class oe{constructor(t,e){this.mapKeyFn=t,this.equalsFn=e,this.inner={},this.innerSize=0}get(t){const e=this.mapKeyFn(t),n=this.inner[e];if(n!==void 0){for(const[i,o]of n)if(this.equalsFn(i,t))return o}}has(t){return this.get(t)!==void 0}set(t,e){const n=this.mapKeyFn(t),i=this.inner[n];if(i===void 0)return this.inner[n]=[[t,e]],void this.innerSize++;for(let o=0;o<i.length;o++)if(this.equalsFn(i[o][0],t))return void(i[o]=[t,e]);i.push([t,e]),this.innerSize++}delete(t){const e=this.mapKeyFn(t),n=this.inner[e];if(n===void 0)return!1;for(let i=0;i<n.length;i++)if(this.equalsFn(n[i][0],t))return n.length===1?delete this.inner[e]:n.splice(i,1),this.innerSize--,!0;return!1}forEach(t){on(this.inner,(e,n)=>{for(const[i,o]of n)t(i,o)})}isEmpty(){return Wu(this.inner)}size(){return this.innerSize}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const yh=new Y(x.comparator);function Wt(){return yh}const Go=new Y(x.comparator);function Ke(...s){let t=Go;for(const e of s)t=t.insert(e.key,e);return t}function Eh(s){let t=Go;return s.forEach((e,n)=>t=t.insert(e,n.overlayedDocument)),t}function ee(){return Xe()}function Ko(){return Xe()}function Xe(){return new oe(s=>s.toString(),(s,t)=>s.isEqual(t))}const Th=new rt(x.comparator);function j(...s){let t=Th;for(const e of s)t=t.add(e);return t}const vh=new rt(F);function Ih(){return vh}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function Ah(s,t){if(s.useProto3Json){if(isNaN(t))return{doubleValue:"NaN"};if(t===1/0)return{doubleValue:"Infinity"};if(t===-1/0)return{doubleValue:"-Infinity"}}return{doubleValue:Mr(t)?"-0":t}}function wh(s){return{integerValue:""+s}}/**
 * @license
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Zn{constructor(){this._=void 0}}function Rh(s,t,e){return s instanceof zr?function(i,o){const u={fields:{[bo]:{stringValue:ko},[Oo]:{timestampValue:{seconds:i.seconds,nanos:i.nanoseconds}}}};return o&&ts(o)&&(o=Wn(o)),o&&(u.fields[xo]=o),{mapValue:u}}(e,t):s instanceof Bn?$o(s,t):s instanceof zn?Qo(s,t):function(i,o){const u=Sh(i,o),l=Bi(u)+Bi(i.Ae);return Ur(u)&&Ur(i.Ae)?wh(l):Ah(i.serializer,l)}(s,t)}function Ph(s,t,e){return s instanceof Bn?$o(s,t):s instanceof zn?Qo(s,t):e}function Sh(s,t){return s instanceof Gr?function(n){return Ur(n)||function(o){return!!o&&"doubleValue"in o}(n)}(t)?t:{integerValue:0}:null}class zr extends Zn{}class Bn extends Zn{constructor(t){super(),this.elements=t}}function $o(s,t){const e=Ho(t);for(const n of s.elements)e.some(i=>Vt(i,n))||e.push(n);return{arrayValue:{values:e}}}class zn extends Zn{constructor(t){super(),this.elements=t}}function Qo(s,t){let e=Ho(t);for(const n of s.elements)e=e.filter(i=>!Vt(i,n));return{arrayValue:{values:e}}}class Gr extends Zn{constructor(t,e){super(),this.serializer=t,this.Ae=e}}function Bi(s){return X(s.integerValue||s.doubleValue)}function Ho(s){return es(s)&&s.arrayValue.values?s.arrayValue.values.slice():[]}function Vh(s,t){return s.field.isEqual(t.field)&&function(n,i){return n instanceof Bn&&i instanceof Bn||n instanceof zn&&i instanceof zn?ye(n.elements,i.elements,Vt):n instanceof Gr&&i instanceof Gr?Vt(n.Ae,i.Ae):n instanceof zr&&i instanceof zr}(s.transform,t.transform)}class re{constructor(t,e){this.updateTime=t,this.exists=e}static none(){return new re}static exists(t){return new re(void 0,t)}static updateTime(t){return new re(t)}get isNone(){return this.updateTime===void 0&&this.exists===void 0}isEqual(t){return this.exists===t.exists&&(this.updateTime?!!t.updateTime&&this.updateTime.isEqual(t.updateTime):!t.updateTime)}}function Mn(s,t){return s.updateTime!==void 0?t.isFoundDocument()&&t.version.isEqual(s.updateTime):s.exists===void 0||s.exists===t.isFoundDocument()}class is{}function Wo(s,t){if(!s.hasLocalMutations||t&&t.fields.length===0)return null;if(t===null)return s.isNoDocument()?new Dh(s.key,re.none()):new os(s.key,s.data,re.none());{const e=s.data,n=Rt.empty();let i=new rt(Et.comparator);for(let o of t.fields)if(!i.has(o)){let u=e.field(o);u===null&&o.length>1&&(o=o.popLast(),u=e.field(o)),u===null?n.delete(o):n.set(o,u),i=i.add(o)}return new tr(s.key,n,new qt(i.toArray()),re.none())}}function Ch(s,t,e){s instanceof os?function(i,o,u){const l=i.value.clone(),f=Gi(i.fieldTransforms,o,u.transformResults);l.setAll(f),o.convertToFoundDocument(u.version,l).setHasCommittedMutations()}(s,t,e):s instanceof tr?function(i,o,u){if(!Mn(i.precondition,o))return void o.convertToUnknownDocument(u.version);const l=Gi(i.fieldTransforms,o,u.transformResults),f=o.data;f.setAll(Xo(i)),f.setAll(l),o.convertToFoundDocument(u.version,f).setHasCommittedMutations()}(s,t,e):function(i,o,u){o.convertToNoDocument(u.version).setHasCommittedMutations()}(0,t,e)}function Ye(s,t,e,n){return s instanceof os?function(o,u,l,f){if(!Mn(o.precondition,u))return l;const d=o.value.clone(),_=Ki(o.fieldTransforms,f,u);return d.setAll(_),u.convertToFoundDocument(u.version,d).setHasLocalMutations(),null}(s,t,e,n):s instanceof tr?function(o,u,l,f){if(!Mn(o.precondition,u))return l;const d=Ki(o.fieldTransforms,f,u),_=u.data;return _.setAll(Xo(o)),_.setAll(d),u.convertToFoundDocument(u.version,_).setHasLocalMutations(),l===null?null:l.unionWith(o.fieldMask.fields).unionWith(o.fieldTransforms.map(w=>w.field))}(s,t,e,n):function(o,u,l){return Mn(o.precondition,u)?(u.convertToNoDocument(u.version).setHasLocalMutations(),null):l}(s,t,e)}function zi(s,t){return s.type===t.type&&!!s.key.isEqual(t.key)&&!!s.precondition.isEqual(t.precondition)&&!!function(n,i){return n===void 0&&i===void 0||!(!n||!i)&&ye(n,i,(o,u)=>Vh(o,u))}(s.fieldTransforms,t.fieldTransforms)&&(s.type===0?s.value.isEqual(t.value):s.type!==1||s.data.isEqual(t.data)&&s.fieldMask.isEqual(t.fieldMask))}class os extends is{constructor(t,e,n,i=[]){super(),this.key=t,this.value=e,this.precondition=n,this.fieldTransforms=i,this.type=0}getFieldMask(){return null}}class tr extends is{constructor(t,e,n,i,o=[]){super(),this.key=t,this.data=e,this.fieldMask=n,this.precondition=i,this.fieldTransforms=o,this.type=1}getFieldMask(){return this.fieldMask}}function Xo(s){const t=new Map;return s.fieldMask.fields.forEach(e=>{if(!e.isEmpty()){const n=s.data.field(e);t.set(e,n)}}),t}function Gi(s,t,e){const n=new Map;H(s.length===e.length,32656,{Re:e.length,Ve:s.length});for(let i=0;i<e.length;i++){const o=s[i],u=o.transform,l=t.data.field(o.field);n.set(o.field,Ph(u,l,e[i]))}return n}function Ki(s,t,e){const n=new Map;for(const i of s){const o=i.transform,u=e.data.field(i.field);n.set(i.field,Rh(o,u,t))}return n}class Dh extends is{constructor(t,e){super(),this.key=t,this.precondition=e,this.type=2,this.fieldTransforms=[]}getFieldMask(){return null}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Nh{constructor(t,e,n,i){this.batchId=t,this.localWriteTime=e,this.baseMutations=n,this.mutations=i}applyToRemoteDocument(t,e){const n=e.mutationResults;for(let i=0;i<this.mutations.length;i++){const o=this.mutations[i];o.key.isEqual(t.key)&&Ch(o,t,n[i])}}applyToLocalView(t,e){for(const n of this.baseMutations)n.key.isEqual(t.key)&&(e=Ye(n,t,e,this.localWriteTime));for(const n of this.mutations)n.key.isEqual(t.key)&&(e=Ye(n,t,e,this.localWriteTime));return e}applyToLocalDocumentSet(t,e){const n=Ko();return this.mutations.forEach(i=>{const o=t.get(i.key),u=o.overlayedDocument;let l=this.applyToLocalView(u,o.mutatedFields);l=e.has(i.key)?null:l;const f=Wo(u,l);f!==null&&n.set(i.key,f),u.isValidDocument()||u.convertToNoDocument(O.min())}),n}keys(){return this.mutations.reduce((t,e)=>t.add(e.key),j())}isEqual(t){return this.batchId===t.batchId&&ye(this.mutations,t.mutations,(e,n)=>zi(e,n))&&ye(this.baseMutations,t.baseMutations,(e,n)=>zi(e,n))}}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class kh{constructor(t,e){this.largestBatchId=t,this.mutation=e}getKey(){return this.mutation.key}isEqual(t){return t!==null&&this.mutation===t.mutation}toString(){return`Overlay{
      largestBatchId: ${this.largestBatchId},
      mutation: ${this.mutation.toString()}
    }`}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class bh{constructor(t,e){this.count=t,this.unchangedNames=e}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */var J,U;function Yo(s){if(s===void 0)return Ot("GRPC error has no .code"),S.UNKNOWN;switch(s){case J.OK:return S.OK;case J.CANCELLED:return S.CANCELLED;case J.UNKNOWN:return S.UNKNOWN;case J.DEADLINE_EXCEEDED:return S.DEADLINE_EXCEEDED;case J.RESOURCE_EXHAUSTED:return S.RESOURCE_EXHAUSTED;case J.INTERNAL:return S.INTERNAL;case J.UNAVAILABLE:return S.UNAVAILABLE;case J.UNAUTHENTICATED:return S.UNAUTHENTICATED;case J.INVALID_ARGUMENT:return S.INVALID_ARGUMENT;case J.NOT_FOUND:return S.NOT_FOUND;case J.ALREADY_EXISTS:return S.ALREADY_EXISTS;case J.PERMISSION_DENIED:return S.PERMISSION_DENIED;case J.FAILED_PRECONDITION:return S.FAILED_PRECONDITION;case J.ABORTED:return S.ABORTED;case J.OUT_OF_RANGE:return S.OUT_OF_RANGE;case J.UNIMPLEMENTED:return S.UNIMPLEMENTED;case J.DATA_LOSS:return S.DATA_LOSS;default:return L(39323,{code:s})}}(U=J||(J={}))[U.OK=0]="OK",U[U.CANCELLED=1]="CANCELLED",U[U.UNKNOWN=2]="UNKNOWN",U[U.INVALID_ARGUMENT=3]="INVALID_ARGUMENT",U[U.DEADLINE_EXCEEDED=4]="DEADLINE_EXCEEDED",U[U.NOT_FOUND=5]="NOT_FOUND",U[U.ALREADY_EXISTS=6]="ALREADY_EXISTS",U[U.PERMISSION_DENIED=7]="PERMISSION_DENIED",U[U.UNAUTHENTICATED=16]="UNAUTHENTICATED",U[U.RESOURCE_EXHAUSTED=8]="RESOURCE_EXHAUSTED",U[U.FAILED_PRECONDITION=9]="FAILED_PRECONDITION",U[U.ABORTED=10]="ABORTED",U[U.OUT_OF_RANGE=11]="OUT_OF_RANGE",U[U.UNIMPLEMENTED=12]="UNIMPLEMENTED",U[U.INTERNAL=13]="INTERNAL",U[U.UNAVAILABLE=14]="UNAVAILABLE",U[U.DATA_LOSS=15]="DATA_LOSS";/**
 * @license
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function xh(){return new TextEncoder}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Oh=new Bt([4294967295,4294967295],0);function $i(s){const t=xh().encode(s),e=new Io;return e.update(t),new Uint8Array(e.digest())}function Qi(s){const t=new DataView(s.buffer),e=t.getUint32(0,!0),n=t.getUint32(4,!0),i=t.getUint32(8,!0),o=t.getUint32(12,!0);return[new Bt([e,n],0),new Bt([i,o],0)]}class as{constructor(t,e,n){if(this.bitmap=t,this.padding=e,this.hashCount=n,e<0||e>=8)throw new $e(`Invalid padding: ${e}`);if(n<0)throw new $e(`Invalid hash count: ${n}`);if(t.length>0&&this.hashCount===0)throw new $e(`Invalid hash count: ${n}`);if(t.length===0&&e!==0)throw new $e(`Invalid padding when bitmap length is 0: ${e}`);this.ge=8*t.length-e,this.pe=Bt.fromNumber(this.ge)}ye(t,e,n){let i=t.add(e.multiply(Bt.fromNumber(n)));return i.compare(Oh)===1&&(i=new Bt([i.getBits(0),i.getBits(1)],0)),i.modulo(this.pe).toNumber()}we(t){return!!(this.bitmap[Math.floor(t/8)]&1<<t%8)}mightContain(t){if(this.ge===0)return!1;const e=$i(t),[n,i]=Qi(e);for(let o=0;o<this.hashCount;o++){const u=this.ye(n,i,o);if(!this.we(u))return!1}return!0}static create(t,e,n){const i=t%8==0?0:8-t%8,o=new Uint8Array(Math.ceil(t/8)),u=new as(o,i,e);return n.forEach(l=>u.insert(l)),u}insert(t){if(this.ge===0)return;const e=$i(t),[n,i]=Qi(e);for(let o=0;o<this.hashCount;o++){const u=this.ye(n,i,o);this.Se(u)}}Se(t){const e=Math.floor(t/8),n=t%8;this.bitmap[e]|=1<<n}}class $e extends Error{constructor(){super(...arguments),this.name="BloomFilterError"}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class er{constructor(t,e,n,i,o){this.snapshotVersion=t,this.targetChanges=e,this.targetMismatches=n,this.documentUpdates=i,this.resolvedLimboDocuments=o}static createSynthesizedRemoteEventForCurrentChange(t,e,n){const i=new Map;return i.set(t,an.createSynthesizedTargetChangeForCurrentChange(t,e,n)),new er(O.min(),i,new Y(F),Wt(),j())}}class an{constructor(t,e,n,i,o){this.resumeToken=t,this.current=e,this.addedDocuments=n,this.modifiedDocuments=i,this.removedDocuments=o}static createSynthesizedTargetChangeForCurrentChange(t,e,n){return new an(n,e,j(),j(),j())}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Ln{constructor(t,e,n,i){this.be=t,this.removedTargetIds=e,this.key=n,this.De=i}}class Jo{constructor(t,e){this.targetId=t,this.Ce=e}}class Zo{constructor(t,e,n=ht.EMPTY_BYTE_STRING,i=null){this.state=t,this.targetIds=e,this.resumeToken=n,this.cause=i}}class Hi{constructor(){this.ve=0,this.Fe=Wi(),this.Me=ht.EMPTY_BYTE_STRING,this.xe=!1,this.Oe=!0}get current(){return this.xe}get resumeToken(){return this.Me}get Ne(){return this.ve!==0}get Be(){return this.Oe}Le(t){t.approximateByteSize()>0&&(this.Oe=!0,this.Me=t)}ke(){let t=j(),e=j(),n=j();return this.Fe.forEach((i,o)=>{switch(o){case 0:t=t.add(i);break;case 2:e=e.add(i);break;case 1:n=n.add(i);break;default:L(38017,{changeType:o})}}),new an(this.Me,this.xe,t,e,n)}qe(){this.Oe=!1,this.Fe=Wi()}Qe(t,e){this.Oe=!0,this.Fe=this.Fe.insert(t,e)}$e(t){this.Oe=!0,this.Fe=this.Fe.remove(t)}Ue(){this.ve+=1}Ke(){this.ve-=1,H(this.ve>=0,3241,{ve:this.ve})}We(){this.Oe=!0,this.xe=!0}}class Mh{constructor(t){this.Ge=t,this.ze=new Map,this.je=Wt(),this.Je=kn(),this.He=kn(),this.Ye=new Y(F)}Ze(t){for(const e of t.be)t.De&&t.De.isFoundDocument()?this.Xe(e,t.De):this.et(e,t.key,t.De);for(const e of t.removedTargetIds)this.et(e,t.key,t.De)}tt(t){this.forEachTarget(t,e=>{const n=this.nt(e);switch(t.state){case 0:this.rt(e)&&n.Le(t.resumeToken);break;case 1:n.Ke(),n.Ne||n.qe(),n.Le(t.resumeToken);break;case 2:n.Ke(),n.Ne||this.removeTarget(e);break;case 3:this.rt(e)&&(n.We(),n.Le(t.resumeToken));break;case 4:this.rt(e)&&(this.it(e),n.Le(t.resumeToken));break;default:L(56790,{state:t.state})}})}forEachTarget(t,e){t.targetIds.length>0?t.targetIds.forEach(e):this.ze.forEach((n,i)=>{this.rt(i)&&e(i)})}st(t){const e=t.targetId,n=t.Ce.count,i=this.ot(e);if(i){const o=i.target;if(jr(o))if(n===0){const u=new x(o.path);this.et(e,u,pt.newNoDocument(u,O.min()))}else H(n===1,20013,{expectedCount:n});else{const u=this._t(e);if(u!==n){const l=this.ut(t),f=l?this.ct(l,t,u):1;if(f!==0){this.it(e);const d=f===2?"TargetPurposeExistenceFilterMismatchBloom":"TargetPurposeExistenceFilterMismatch";this.Ye=this.Ye.insert(e,d)}}}}}ut(t){const e=t.Ce.unchangedNames;if(!e||!e.bits)return null;const{bits:{bitmap:n="",padding:i=0},hashCount:o=0}=e;let u,l;try{u=Qt(n).toUint8Array()}catch(f){if(f instanceof No)return _e("Decoding the base64 bloom filter in existence filter failed ("+f.message+"); ignoring the bloom filter and falling back to full re-query."),null;throw f}try{l=new as(u,i,o)}catch(f){return _e(f instanceof $e?"BloomFilter error: ":"Applying bloom filter failed: ",f),null}return l.ge===0?null:l}ct(t,e,n){return e.Ce.count===n-this.Pt(t,e.targetId)?0:2}Pt(t,e){const n=this.Ge.getRemoteKeysForTarget(e);let i=0;return n.forEach(o=>{const u=this.Ge.ht(),l=`projects/${u.projectId}/databases/${u.database}/documents/${o.path.canonicalString()}`;t.mightContain(l)||(this.et(e,o,null),i++)}),i}Tt(t){const e=new Map;this.ze.forEach((o,u)=>{const l=this.ot(u);if(l){if(o.current&&jr(l.target)){const f=new x(l.target.path);this.It(f).has(u)||this.Et(u,f)||this.et(u,f,pt.newNoDocument(f,t))}o.Be&&(e.set(u,o.ke()),o.qe())}});let n=j();this.He.forEach((o,u)=>{let l=!0;u.forEachWhile(f=>{const d=this.ot(f);return!d||d.purpose==="TargetPurposeLimboResolution"||(l=!1,!1)}),l&&(n=n.add(o))}),this.je.forEach((o,u)=>u.setReadTime(t));const i=new er(t,e,this.Ye,this.je,n);return this.je=Wt(),this.Je=kn(),this.He=kn(),this.Ye=new Y(F),i}Xe(t,e){if(!this.rt(t))return;const n=this.Et(t,e.key)?2:0;this.nt(t).Qe(e.key,n),this.je=this.je.insert(e.key,e),this.Je=this.Je.insert(e.key,this.It(e.key).add(t)),this.He=this.He.insert(e.key,this.dt(e.key).add(t))}et(t,e,n){if(!this.rt(t))return;const i=this.nt(t);this.Et(t,e)?i.Qe(e,1):i.$e(e),this.He=this.He.insert(e,this.dt(e).delete(t)),this.He=this.He.insert(e,this.dt(e).add(t)),n&&(this.je=this.je.insert(e,n))}removeTarget(t){this.ze.delete(t)}_t(t){const e=this.nt(t).ke();return this.Ge.getRemoteKeysForTarget(t).size+e.addedDocuments.size-e.removedDocuments.size}Ue(t){this.nt(t).Ue()}nt(t){let e=this.ze.get(t);return e||(e=new Hi,this.ze.set(t,e)),e}dt(t){let e=this.He.get(t);return e||(e=new rt(F),this.He=this.He.insert(t,e)),e}It(t){let e=this.Je.get(t);return e||(e=new rt(F),this.Je=this.Je.insert(t,e)),e}rt(t){const e=this.ot(t)!==null;return e||D("WatchChangeAggregator","Detected inactive target",t),e}ot(t){const e=this.ze.get(t);return e&&e.Ne?null:this.Ge.At(t)}it(t){this.ze.set(t,new Hi),this.Ge.getRemoteKeysForTarget(t).forEach(e=>{this.et(t,e,null)})}Et(t,e){return this.Ge.getRemoteKeysForTarget(t).has(e)}}function kn(){return new Y(x.comparator)}function Wi(){return new Y(x.comparator)}const Lh={asc:"ASCENDING",desc:"DESCENDING"},Fh={"<":"LESS_THAN","<=":"LESS_THAN_OR_EQUAL",">":"GREATER_THAN",">=":"GREATER_THAN_OR_EQUAL","==":"EQUAL","!=":"NOT_EQUAL","array-contains":"ARRAY_CONTAINS",in:"IN","not-in":"NOT_IN","array-contains-any":"ARRAY_CONTAINS_ANY"},Uh={and:"AND",or:"OR"};class qh{constructor(t,e){this.databaseId=t,this.useProto3Json=e}}function Kr(s,t){return s.useProto3Json||Hn(t)?t:{value:t}}function jh(s,t){return s.useProto3Json?`${new Date(1e3*t.seconds).toISOString().replace(/\.\d*/,"").replace("Z","")}.${("000000000"+t.nanoseconds).slice(-9)}Z`:{seconds:""+t.seconds,nanos:t.nanoseconds}}function Bh(s,t){return s.useProto3Json?t.toBase64():t.toUint8Array()}function ge(s){return H(!!s,49232),O.fromTimestamp(function(e){const n=$t(e);return new Z(n.seconds,n.nanos)}(s))}function zh(s,t){return $r(s,t).canonicalString()}function $r(s,t){const e=function(i){return new Q(["projects",i.projectId,"databases",i.database])}(s).child("documents");return t===void 0?e:e.child(t)}function ta(s){const t=Q.fromString(s);return H(ia(t),10190,{key:t.toString()}),t}function Cr(s,t){const e=ta(t);if(e.get(1)!==s.databaseId.projectId)throw new k(S.INVALID_ARGUMENT,"Tried to deserialize key from different project: "+e.get(1)+" vs "+s.databaseId.projectId);if(e.get(3)!==s.databaseId.database)throw new k(S.INVALID_ARGUMENT,"Tried to deserialize key from different database: "+e.get(3)+" vs "+s.databaseId.database);return new x(na(e))}function ea(s,t){return zh(s.databaseId,t)}function Gh(s){const t=ta(s);return t.length===4?Q.emptyPath():na(t)}function Xi(s){return new Q(["projects",s.databaseId.projectId,"databases",s.databaseId.database]).canonicalString()}function na(s){return H(s.length>4&&s.get(4)==="documents",29091,{key:s.toString()}),s.popFirst(5)}function Kh(s,t){let e;if("targetChange"in t){t.targetChange;const n=function(d){return d==="NO_CHANGE"?0:d==="ADD"?1:d==="REMOVE"?2:d==="CURRENT"?3:d==="RESET"?4:L(39313,{state:d})}(t.targetChange.targetChangeType||"NO_CHANGE"),i=t.targetChange.targetIds||[],o=function(d,_){return d.useProto3Json?(H(_===void 0||typeof _=="string",58123),ht.fromBase64String(_||"")):(H(_===void 0||_ instanceof Buffer||_ instanceof Uint8Array,16193),ht.fromUint8Array(_||new Uint8Array))}(s,t.targetChange.resumeToken),u=t.targetChange.cause,l=u&&function(d){const _=d.code===void 0?S.UNKNOWN:Yo(d.code);return new k(_,d.message||"")}(u);e=new Zo(n,i,o,l||null)}else if("documentChange"in t){t.documentChange;const n=t.documentChange;n.document,n.document.name,n.document.updateTime;const i=Cr(s,n.document.name),o=ge(n.document.updateTime),u=n.document.createTime?ge(n.document.createTime):O.min(),l=new Rt({mapValue:{fields:n.document.fields}}),f=pt.newFoundDocument(i,o,u,l),d=n.targetIds||[],_=n.removedTargetIds||[];e=new Ln(d,_,f.key,f)}else if("documentDelete"in t){t.documentDelete;const n=t.documentDelete;n.document;const i=Cr(s,n.document),o=n.readTime?ge(n.readTime):O.min(),u=pt.newNoDocument(i,o),l=n.removedTargetIds||[];e=new Ln([],l,u.key,u)}else if("documentRemove"in t){t.documentRemove;const n=t.documentRemove;n.document;const i=Cr(s,n.document),o=n.removedTargetIds||[];e=new Ln([],o,i,null)}else{if(!("filter"in t))return L(11601,{Rt:t});{t.filter;const n=t.filter;n.targetId;const{count:i=0,unchangedNames:o}=n,u=new bh(i,o),l=n.targetId;e=new Jo(l,u)}}return e}function $h(s,t){return{documents:[ea(s,t.path)]}}function Qh(s,t){const e={structuredQuery:{}},n=t.path;let i;t.collectionGroup!==null?(i=n,e.structuredQuery.from=[{collectionId:t.collectionGroup,allDescendants:!0}]):(i=n.popLast(),e.structuredQuery.from=[{collectionId:n.lastSegment()}]),e.parent=ea(s,i);const o=function(d){if(d.length!==0)return sa(Ct.create(d,"and"))}(t.filters);o&&(e.structuredQuery.where=o);const u=function(d){if(d.length!==0)return d.map(_=>function(P){return{field:de(P.field),direction:Xh(P.dir)}}(_))}(t.orderBy);u&&(e.structuredQuery.orderBy=u);const l=Kr(s,t.limit);return l!==null&&(e.structuredQuery.limit=l),t.startAt&&(e.structuredQuery.startAt=function(d){return{before:d.inclusive,values:d.position}}(t.startAt)),t.endAt&&(e.structuredQuery.endAt=function(d){return{before:!d.inclusive,values:d.position}}(t.endAt)),{ft:e,parent:i}}function Hh(s){let t=Gh(s.parent);const e=s.structuredQuery,n=e.from?e.from.length:0;let i=null;if(n>0){H(n===1,65062);const _=e.from[0];_.allDescendants?i=_.collectionId:t=t.child(_.collectionId)}let o=[];e.where&&(o=function(w){const P=ra(w);return P instanceof Ct&&Fo(P)?P.getFilters():[P]}(e.where));let u=[];e.orderBy&&(u=function(w){return w.map(P=>function(b){return new jn(me(b.field),function(N){switch(N){case"ASCENDING":return"asc";case"DESCENDING":return"desc";default:return}}(b.direction))}(P))}(e.orderBy));let l=null;e.limit&&(l=function(w){let P;return P=typeof w=="object"?w.value:w,Hn(P)?null:P}(e.limit));let f=null;e.startAt&&(f=function(w){const P=!!w.before,C=w.values||[];return new qn(C,P)}(e.startAt));let d=null;return e.endAt&&(d=function(w){const P=!w.before,C=w.values||[];return new qn(C,P)}(e.endAt)),dh(t,i,u,o,l,"F",f,d)}function Wh(s,t){const e=function(i){switch(i){case"TargetPurposeListen":return null;case"TargetPurposeExistenceFilterMismatch":return"existence-filter-mismatch";case"TargetPurposeExistenceFilterMismatchBloom":return"existence-filter-mismatch-bloom";case"TargetPurposeLimboResolution":return"limbo-document";default:return L(28987,{purpose:i})}}(t.purpose);return e==null?null:{"goog-listen-tags":e}}function ra(s){return s.unaryFilter!==void 0?function(e){switch(e.unaryFilter.op){case"IS_NAN":const n=me(e.unaryFilter.field);return nt.create(n,"==",{doubleValue:NaN});case"IS_NULL":const i=me(e.unaryFilter.field);return nt.create(i,"==",{nullValue:"NULL_VALUE"});case"IS_NOT_NAN":const o=me(e.unaryFilter.field);return nt.create(o,"!=",{doubleValue:NaN});case"IS_NOT_NULL":const u=me(e.unaryFilter.field);return nt.create(u,"!=",{nullValue:"NULL_VALUE"});case"OPERATOR_UNSPECIFIED":return L(61313);default:return L(60726)}}(s):s.fieldFilter!==void 0?function(e){return nt.create(me(e.fieldFilter.field),function(i){switch(i){case"EQUAL":return"==";case"NOT_EQUAL":return"!=";case"GREATER_THAN":return">";case"GREATER_THAN_OR_EQUAL":return">=";case"LESS_THAN":return"<";case"LESS_THAN_OR_EQUAL":return"<=";case"ARRAY_CONTAINS":return"array-contains";case"IN":return"in";case"NOT_IN":return"not-in";case"ARRAY_CONTAINS_ANY":return"array-contains-any";case"OPERATOR_UNSPECIFIED":return L(58110);default:return L(50506)}}(e.fieldFilter.op),e.fieldFilter.value)}(s):s.compositeFilter!==void 0?function(e){return Ct.create(e.compositeFilter.filters.map(n=>ra(n)),function(i){switch(i){case"AND":return"and";case"OR":return"or";default:return L(1026)}}(e.compositeFilter.op))}(s):L(30097,{filter:s})}function Xh(s){return Lh[s]}function Yh(s){return Fh[s]}function Jh(s){return Uh[s]}function de(s){return{fieldPath:s.canonicalString()}}function me(s){return Et.fromServerFormat(s.fieldPath)}function sa(s){return s instanceof nt?function(e){if(e.op==="=="){if(Li(e.value))return{unaryFilter:{field:de(e.field),op:"IS_NAN"}};if(Mi(e.value))return{unaryFilter:{field:de(e.field),op:"IS_NULL"}}}else if(e.op==="!="){if(Li(e.value))return{unaryFilter:{field:de(e.field),op:"IS_NOT_NAN"}};if(Mi(e.value))return{unaryFilter:{field:de(e.field),op:"IS_NOT_NULL"}}}return{fieldFilter:{field:de(e.field),op:Yh(e.op),value:e.value}}}(s):s instanceof Ct?function(e){const n=e.getFilters().map(i=>sa(i));return n.length===1?n[0]:{compositeFilter:{op:Jh(e.op),filters:n}}}(s):L(54877,{filter:s})}function ia(s){return s.length>=4&&s.get(0)==="projects"&&s.get(2)==="databases"}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class jt{constructor(t,e,n,i,o=O.min(),u=O.min(),l=ht.EMPTY_BYTE_STRING,f=null){this.target=t,this.targetId=e,this.purpose=n,this.sequenceNumber=i,this.snapshotVersion=o,this.lastLimboFreeSnapshotVersion=u,this.resumeToken=l,this.expectedCount=f}withSequenceNumber(t){return new jt(this.target,this.targetId,this.purpose,t,this.snapshotVersion,this.lastLimboFreeSnapshotVersion,this.resumeToken,this.expectedCount)}withResumeToken(t,e){return new jt(this.target,this.targetId,this.purpose,this.sequenceNumber,e,this.lastLimboFreeSnapshotVersion,t,null)}withExpectedCount(t){return new jt(this.target,this.targetId,this.purpose,this.sequenceNumber,this.snapshotVersion,this.lastLimboFreeSnapshotVersion,this.resumeToken,t)}withLastLimboFreeSnapshotVersion(t){return new jt(this.target,this.targetId,this.purpose,this.sequenceNumber,this.snapshotVersion,t,this.resumeToken,this.expectedCount)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Zh{constructor(t){this.yt=t}}function tl(s){const t=Hh({parent:s.parent,structuredQuery:s.structuredQuery});return s.limitType==="LAST"?Br(t,t.limit,"L"):t}/**
 * @license
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class el{constructor(){this.Cn=new nl}addToCollectionParentIndex(t,e){return this.Cn.add(e),R.resolve()}getCollectionParents(t,e){return R.resolve(this.Cn.getEntries(e))}addFieldIndex(t,e){return R.resolve()}deleteFieldIndex(t,e){return R.resolve()}deleteAllFieldIndexes(t){return R.resolve()}createTargetIndexes(t,e){return R.resolve()}getDocumentsMatchingTarget(t,e){return R.resolve(null)}getIndexType(t,e){return R.resolve(0)}getFieldIndexes(t,e){return R.resolve([])}getNextCollectionGroupToUpdate(t){return R.resolve(null)}getMinOffset(t,e){return R.resolve(Kt.min())}getMinOffsetFromCollectionGroup(t,e){return R.resolve(Kt.min())}updateCollectionGroup(t,e,n){return R.resolve()}updateIndexEntries(t,e){return R.resolve()}}class nl{constructor(){this.index={}}add(t){const e=t.lastSegment(),n=t.popLast(),i=this.index[e]||new rt(Q.comparator),o=!i.has(n);return this.index[e]=i.add(n),o}has(t){const e=t.lastSegment(),n=t.popLast(),i=this.index[e];return i&&i.has(n)}getEntries(t){return(this.index[t]||new rt(Q.comparator)).toArray()}}/**
 * @license
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Yi={didRun:!1,sequenceNumbersCollected:0,targetsRemoved:0,documentsRemoved:0},oa=41943040;class vt{static withCacheSize(t){return new vt(t,vt.DEFAULT_COLLECTION_PERCENTILE,vt.DEFAULT_MAX_SEQUENCE_NUMBERS_TO_COLLECT)}constructor(t,e,n){this.cacheSizeCollectionThreshold=t,this.percentileToCollect=e,this.maximumSequenceNumbersToCollect=n}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */vt.DEFAULT_COLLECTION_PERCENTILE=10,vt.DEFAULT_MAX_SEQUENCE_NUMBERS_TO_COLLECT=1e3,vt.DEFAULT=new vt(oa,vt.DEFAULT_COLLECTION_PERCENTILE,vt.DEFAULT_MAX_SEQUENCE_NUMBERS_TO_COLLECT),vt.DISABLED=new vt(-1,0,0);/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ve{constructor(t){this.ar=t}next(){return this.ar+=2,this.ar}static ur(){return new ve(0)}static cr(){return new ve(-1)}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Ji="LruGarbageCollector",rl=1048576;function Zi([s,t],[e,n]){const i=F(s,e);return i===0?F(t,n):i}class sl{constructor(t){this.Ir=t,this.buffer=new rt(Zi),this.Er=0}dr(){return++this.Er}Ar(t){const e=[t,this.dr()];if(this.buffer.size<this.Ir)this.buffer=this.buffer.add(e);else{const n=this.buffer.last();Zi(e,n)<0&&(this.buffer=this.buffer.delete(n).add(e))}}get maxValue(){return this.buffer.last()[0]}}class il{constructor(t,e,n){this.garbageCollector=t,this.asyncQueue=e,this.localStore=n,this.Rr=null}start(){this.garbageCollector.params.cacheSizeCollectionThreshold!==-1&&this.Vr(6e4)}stop(){this.Rr&&(this.Rr.cancel(),this.Rr=null)}get started(){return this.Rr!==null}Vr(t){D(Ji,`Garbage collection scheduled in ${t}ms`),this.Rr=this.asyncQueue.enqueueAfterDelay("lru_garbage_collection",t,async()=>{this.Rr=null;try{await this.localStore.collectGarbage(this.garbageCollector)}catch(e){Re(e)?D(Ji,"Ignoring IndexedDB error during garbage collection: ",e):await $n(e)}await this.Vr(3e5)})}}class ol{constructor(t,e){this.mr=t,this.params=e}calculateTargetCount(t,e){return this.mr.gr(t).next(n=>Math.floor(e/100*n))}nthSequenceNumber(t,e){if(e===0)return R.resolve(Qn.ce);const n=new sl(e);return this.mr.forEachTarget(t,i=>n.Ar(i.sequenceNumber)).next(()=>this.mr.pr(t,i=>n.Ar(i))).next(()=>n.maxValue)}removeTargets(t,e,n){return this.mr.removeTargets(t,e,n)}removeOrphanedDocuments(t,e){return this.mr.removeOrphanedDocuments(t,e)}collect(t,e){return this.params.cacheSizeCollectionThreshold===-1?(D("LruGarbageCollector","Garbage collection skipped; disabled"),R.resolve(Yi)):this.getCacheSize(t).next(n=>n<this.params.cacheSizeCollectionThreshold?(D("LruGarbageCollector",`Garbage collection skipped; Cache size ${n} is lower than threshold ${this.params.cacheSizeCollectionThreshold}`),Yi):this.yr(t,e))}getCacheSize(t){return this.mr.getCacheSize(t)}yr(t,e){let n,i,o,u,l,f,d;const _=Date.now();return this.calculateTargetCount(t,this.params.percentileToCollect).next(w=>(w>this.params.maximumSequenceNumbersToCollect?(D("LruGarbageCollector",`Capping sequence numbers to collect down to the maximum of ${this.params.maximumSequenceNumbersToCollect} from ${w}`),i=this.params.maximumSequenceNumbersToCollect):i=w,u=Date.now(),this.nthSequenceNumber(t,i))).next(w=>(n=w,l=Date.now(),this.removeTargets(t,n,e))).next(w=>(o=w,f=Date.now(),this.removeOrphanedDocuments(t,n))).next(w=>(d=Date.now(),ce()<=xt.DEBUG&&D("LruGarbageCollector",`LRU Garbage Collection
	Counted targets in ${u-_}ms
	Determined least recently used ${i} in `+(l-u)+`ms
	Removed ${o} targets in `+(f-l)+`ms
	Removed ${w} documents in `+(d-f)+`ms
Total Duration: ${d-_}ms`),R.resolve({didRun:!0,sequenceNumbersCollected:i,targetsRemoved:o,documentsRemoved:w})))}}function al(s,t){return new ol(s,t)}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ul{constructor(){this.changes=new oe(t=>t.toString(),(t,e)=>t.isEqual(e)),this.changesApplied=!1}addEntry(t){this.assertNotApplied(),this.changes.set(t.key,t)}removeEntry(t,e){this.assertNotApplied(),this.changes.set(t,pt.newInvalidDocument(t).setReadTime(e))}getEntry(t,e){this.assertNotApplied();const n=this.changes.get(e);return n!==void 0?R.resolve(n):this.getFromCache(t,e)}getEntries(t,e){return this.getAllFromCache(t,e)}apply(t){return this.assertNotApplied(),this.changesApplied=!0,this.applyChanges(t)}assertNotApplied(){}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *//**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class hl{constructor(t,e){this.overlayedDocument=t,this.mutatedFields=e}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ll{constructor(t,e,n,i){this.remoteDocumentCache=t,this.mutationQueue=e,this.documentOverlayCache=n,this.indexManager=i}getDocument(t,e){let n=null;return this.documentOverlayCache.getOverlay(t,e).next(i=>(n=i,this.remoteDocumentCache.getEntry(t,e))).next(i=>(n!==null&&Ye(n.mutation,i,qt.empty(),Z.now()),i))}getDocuments(t,e){return this.remoteDocumentCache.getEntries(t,e).next(n=>this.getLocalViewOfDocuments(t,n,j()).next(()=>n))}getLocalViewOfDocuments(t,e,n=j()){const i=ee();return this.populateOverlays(t,i,e).next(()=>this.computeViews(t,e,i,n).next(o=>{let u=Ke();return o.forEach((l,f)=>{u=u.insert(l,f.overlayedDocument)}),u}))}getOverlayedDocuments(t,e){const n=ee();return this.populateOverlays(t,n,e).next(()=>this.computeViews(t,e,n,j()))}populateOverlays(t,e,n){const i=[];return n.forEach(o=>{e.has(o)||i.push(o)}),this.documentOverlayCache.getOverlays(t,i).next(o=>{o.forEach((u,l)=>{e.set(u,l)})})}computeViews(t,e,n,i){let o=Wt();const u=Xe(),l=function(){return Xe()}();return e.forEach((f,d)=>{const _=n.get(d.key);i.has(d.key)&&(_===void 0||_.mutation instanceof tr)?o=o.insert(d.key,d):_!==void 0?(u.set(d.key,_.mutation.getFieldMask()),Ye(_.mutation,d,_.mutation.getFieldMask(),Z.now())):u.set(d.key,qt.empty())}),this.recalculateAndSaveOverlays(t,o).next(f=>(f.forEach((d,_)=>u.set(d,_)),e.forEach((d,_)=>l.set(d,new hl(_,u.get(d)??null))),l))}recalculateAndSaveOverlays(t,e){const n=Xe();let i=new Y((u,l)=>u-l),o=j();return this.mutationQueue.getAllMutationBatchesAffectingDocumentKeys(t,e).next(u=>{for(const l of u)l.keys().forEach(f=>{const d=e.get(f);if(d===null)return;let _=n.get(f)||qt.empty();_=l.applyToLocalView(d,_),n.set(f,_);const w=(i.get(l.batchId)||j()).add(f);i=i.insert(l.batchId,w)})}).next(()=>{const u=[],l=i.getReverseIterator();for(;l.hasNext();){const f=l.getNext(),d=f.key,_=f.value,w=Ko();_.forEach(P=>{if(!o.has(P)){const C=Wo(e.get(P),n.get(P));C!==null&&w.set(P,C),o=o.add(P)}}),u.push(this.documentOverlayCache.saveOverlays(t,d,w))}return R.waitFor(u)}).next(()=>n)}recalculateAndSaveOverlaysForDocumentKeys(t,e){return this.remoteDocumentCache.getEntries(t,e).next(n=>this.recalculateAndSaveOverlays(t,n))}getDocumentsMatchingQuery(t,e,n,i){return function(u){return x.isDocumentKey(u.path)&&u.collectionGroup===null&&u.filters.length===0}(e)?this.getDocumentsMatchingDocumentQuery(t,e.path):mh(e)?this.getDocumentsMatchingCollectionGroupQuery(t,e,n,i):this.getDocumentsMatchingCollectionQuery(t,e,n,i)}getNextDocuments(t,e,n,i){return this.remoteDocumentCache.getAllFromCollectionGroup(t,e,n,i).next(o=>{const u=i-o.size>0?this.documentOverlayCache.getOverlaysForCollectionGroup(t,e,n.largestBatchId,i-o.size):R.resolve(ee());let l=Ze,f=o;return u.next(d=>R.forEach(d,(_,w)=>(l<w.largestBatchId&&(l=w.largestBatchId),o.get(_)?R.resolve():this.remoteDocumentCache.getEntry(t,_).next(P=>{f=f.insert(_,P)}))).next(()=>this.populateOverlays(t,d,o)).next(()=>this.computeViews(t,f,d,j())).next(_=>({batchId:l,changes:Eh(_)})))})}getDocumentsMatchingDocumentQuery(t,e){return this.getDocument(t,new x(e)).next(n=>{let i=Ke();return n.isFoundDocument()&&(i=i.insert(n.key,n)),i})}getDocumentsMatchingCollectionGroupQuery(t,e,n,i){const o=e.collectionGroup;let u=Ke();return this.indexManager.getCollectionParents(t,o).next(l=>R.forEach(l,f=>{const d=function(w,P){return new Xn(P,null,w.explicitOrderBy.slice(),w.filters.slice(),w.limit,w.limitType,w.startAt,w.endAt)}(e,f.child(o));return this.getDocumentsMatchingCollectionQuery(t,d,n,i).next(_=>{_.forEach((w,P)=>{u=u.insert(w,P)})})}).next(()=>u))}getDocumentsMatchingCollectionQuery(t,e,n,i){let o;return this.documentOverlayCache.getOverlaysForCollection(t,e.path,n.largestBatchId).next(u=>(o=u,this.remoteDocumentCache.getDocumentsMatchingQuery(t,e,n,o,i))).next(u=>{o.forEach((f,d)=>{const _=d.getKey();u.get(_)===null&&(u=u.insert(_,pt.newInvalidDocument(_)))});let l=Ke();return u.forEach((f,d)=>{const _=o.get(f);_!==void 0&&Ye(_.mutation,d,qt.empty(),Z.now()),Jn(e,d)&&(l=l.insert(f,d))}),l})}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class cl{constructor(t){this.serializer=t,this.Lr=new Map,this.kr=new Map}getBundleMetadata(t,e){return R.resolve(this.Lr.get(e))}saveBundleMetadata(t,e){return this.Lr.set(e.id,function(i){return{id:i.id,version:i.version,createTime:ge(i.createTime)}}(e)),R.resolve()}getNamedQuery(t,e){return R.resolve(this.kr.get(e))}saveNamedQuery(t,e){return this.kr.set(e.name,function(i){return{name:i.name,query:tl(i.bundledQuery),readTime:ge(i.readTime)}}(e)),R.resolve()}}/**
 * @license
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class fl{constructor(){this.overlays=new Y(x.comparator),this.qr=new Map}getOverlay(t,e){return R.resolve(this.overlays.get(e))}getOverlays(t,e){const n=ee();return R.forEach(e,i=>this.getOverlay(t,i).next(o=>{o!==null&&n.set(i,o)})).next(()=>n)}saveOverlays(t,e,n){return n.forEach((i,o)=>{this.St(t,e,o)}),R.resolve()}removeOverlaysForBatchId(t,e,n){const i=this.qr.get(n);return i!==void 0&&(i.forEach(o=>this.overlays=this.overlays.remove(o)),this.qr.delete(n)),R.resolve()}getOverlaysForCollection(t,e,n){const i=ee(),o=e.length+1,u=new x(e.child("")),l=this.overlays.getIteratorFrom(u);for(;l.hasNext();){const f=l.getNext().value,d=f.getKey();if(!e.isPrefixOf(d.path))break;d.path.length===o&&f.largestBatchId>n&&i.set(f.getKey(),f)}return R.resolve(i)}getOverlaysForCollectionGroup(t,e,n,i){let o=new Y((d,_)=>d-_);const u=this.overlays.getIterator();for(;u.hasNext();){const d=u.getNext().value;if(d.getKey().getCollectionGroup()===e&&d.largestBatchId>n){let _=o.get(d.largestBatchId);_===null&&(_=ee(),o=o.insert(d.largestBatchId,_)),_.set(d.getKey(),d)}}const l=ee(),f=o.getIterator();for(;f.hasNext()&&(f.getNext().value.forEach((d,_)=>l.set(d,_)),!(l.size()>=i)););return R.resolve(l)}St(t,e,n){const i=this.overlays.get(n.key);if(i!==null){const u=this.qr.get(i.largestBatchId).delete(n.key);this.qr.set(i.largestBatchId,u)}this.overlays=this.overlays.insert(n.key,new kh(e,n));let o=this.qr.get(e);o===void 0&&(o=j(),this.qr.set(e,o)),this.qr.set(e,o.add(n.key))}}/**
 * @license
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class dl{constructor(){this.sessionToken=ht.EMPTY_BYTE_STRING}getSessionToken(t){return R.resolve(this.sessionToken)}setSessionToken(t,e){return this.sessionToken=e,R.resolve()}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class us{constructor(){this.Qr=new rt(it.$r),this.Ur=new rt(it.Kr)}isEmpty(){return this.Qr.isEmpty()}addReference(t,e){const n=new it(t,e);this.Qr=this.Qr.add(n),this.Ur=this.Ur.add(n)}Wr(t,e){t.forEach(n=>this.addReference(n,e))}removeReference(t,e){this.Gr(new it(t,e))}zr(t,e){t.forEach(n=>this.removeReference(n,e))}jr(t){const e=new x(new Q([])),n=new it(e,t),i=new it(e,t+1),o=[];return this.Ur.forEachInRange([n,i],u=>{this.Gr(u),o.push(u.key)}),o}Jr(){this.Qr.forEach(t=>this.Gr(t))}Gr(t){this.Qr=this.Qr.delete(t),this.Ur=this.Ur.delete(t)}Hr(t){const e=new x(new Q([])),n=new it(e,t),i=new it(e,t+1);let o=j();return this.Ur.forEachInRange([n,i],u=>{o=o.add(u.key)}),o}containsKey(t){const e=new it(t,0),n=this.Qr.firstAfterOrEqual(e);return n!==null&&t.isEqual(n.key)}}class it{constructor(t,e){this.key=t,this.Yr=e}static $r(t,e){return x.comparator(t.key,e.key)||F(t.Yr,e.Yr)}static Kr(t,e){return F(t.Yr,e.Yr)||x.comparator(t.key,e.key)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ml{constructor(t,e){this.indexManager=t,this.referenceDelegate=e,this.mutationQueue=[],this.tr=1,this.Zr=new rt(it.$r)}checkEmpty(t){return R.resolve(this.mutationQueue.length===0)}addMutationBatch(t,e,n,i){const o=this.tr;this.tr++,this.mutationQueue.length>0&&this.mutationQueue[this.mutationQueue.length-1];const u=new Nh(o,e,n,i);this.mutationQueue.push(u);for(const l of i)this.Zr=this.Zr.add(new it(l.key,o)),this.indexManager.addToCollectionParentIndex(t,l.key.path.popLast());return R.resolve(u)}lookupMutationBatch(t,e){return R.resolve(this.Xr(e))}getNextMutationBatchAfterBatchId(t,e){const n=e+1,i=this.ei(n),o=i<0?0:i;return R.resolve(this.mutationQueue.length>o?this.mutationQueue[o]:null)}getHighestUnacknowledgedBatchId(){return R.resolve(this.mutationQueue.length===0?$u:this.tr-1)}getAllMutationBatches(t){return R.resolve(this.mutationQueue.slice())}getAllMutationBatchesAffectingDocumentKey(t,e){const n=new it(e,0),i=new it(e,Number.POSITIVE_INFINITY),o=[];return this.Zr.forEachInRange([n,i],u=>{const l=this.Xr(u.Yr);o.push(l)}),R.resolve(o)}getAllMutationBatchesAffectingDocumentKeys(t,e){let n=new rt(F);return e.forEach(i=>{const o=new it(i,0),u=new it(i,Number.POSITIVE_INFINITY);this.Zr.forEachInRange([o,u],l=>{n=n.add(l.Yr)})}),R.resolve(this.ti(n))}getAllMutationBatchesAffectingQuery(t,e){const n=e.path,i=n.length+1;let o=n;x.isDocumentKey(o)||(o=o.child(""));const u=new it(new x(o),0);let l=new rt(F);return this.Zr.forEachWhile(f=>{const d=f.key.path;return!!n.isPrefixOf(d)&&(d.length===i&&(l=l.add(f.Yr)),!0)},u),R.resolve(this.ti(l))}ti(t){const e=[];return t.forEach(n=>{const i=this.Xr(n);i!==null&&e.push(i)}),e}removeMutationBatch(t,e){H(this.ni(e.batchId,"removed")===0,55003),this.mutationQueue.shift();let n=this.Zr;return R.forEach(e.mutations,i=>{const o=new it(i.key,e.batchId);return n=n.delete(o),this.referenceDelegate.markPotentiallyOrphaned(t,i.key)}).next(()=>{this.Zr=n})}ir(t){}containsKey(t,e){const n=new it(e,0),i=this.Zr.firstAfterOrEqual(n);return R.resolve(e.isEqual(i&&i.key))}performConsistencyCheck(t){return this.mutationQueue.length,R.resolve()}ni(t,e){return this.ei(t)}ei(t){return this.mutationQueue.length===0?0:t-this.mutationQueue[0].batchId}Xr(t){const e=this.ei(t);return e<0||e>=this.mutationQueue.length?null:this.mutationQueue[e]}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class gl{constructor(t){this.ri=t,this.docs=function(){return new Y(x.comparator)}(),this.size=0}setIndexManager(t){this.indexManager=t}addEntry(t,e){const n=e.key,i=this.docs.get(n),o=i?i.size:0,u=this.ri(e);return this.docs=this.docs.insert(n,{document:e.mutableCopy(),size:u}),this.size+=u-o,this.indexManager.addToCollectionParentIndex(t,n.path.popLast())}removeEntry(t){const e=this.docs.get(t);e&&(this.docs=this.docs.remove(t),this.size-=e.size)}getEntry(t,e){const n=this.docs.get(e);return R.resolve(n?n.document.mutableCopy():pt.newInvalidDocument(e))}getEntries(t,e){let n=Wt();return e.forEach(i=>{const o=this.docs.get(i);n=n.insert(i,o?o.document.mutableCopy():pt.newInvalidDocument(i))}),R.resolve(n)}getDocumentsMatchingQuery(t,e,n,i){let o=Wt();const u=e.path,l=new x(u.child("__id-9223372036854775808__")),f=this.docs.getIteratorFrom(l);for(;f.hasNext();){const{key:d,value:{document:_}}=f.getNext();if(!u.isPrefixOf(d.path))break;d.path.length>u.length+1||Bu(ju(_),n)<=0||(i.has(_.key)||Jn(e,_))&&(o=o.insert(_.key,_.mutableCopy()))}return R.resolve(o)}getAllFromCollectionGroup(t,e,n,i){L(9500)}ii(t,e){return R.forEach(this.docs,n=>e(n))}newChangeBuffer(t){return new pl(this)}getSize(t){return R.resolve(this.size)}}class pl extends ul{constructor(t){super(),this.Nr=t}applyChanges(t){const e=[];return this.changes.forEach((n,i)=>{i.isValidDocument()?e.push(this.Nr.addEntry(t,i)):this.Nr.removeEntry(n)}),R.waitFor(e)}getFromCache(t,e){return this.Nr.getEntry(t,e)}getAllFromCache(t,e){return this.Nr.getEntries(t,e)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class _l{constructor(t){this.persistence=t,this.si=new oe(e=>ns(e),rs),this.lastRemoteSnapshotVersion=O.min(),this.highestTargetId=0,this.oi=0,this._i=new us,this.targetCount=0,this.ai=ve.ur()}forEachTarget(t,e){return this.si.forEach((n,i)=>e(i)),R.resolve()}getLastRemoteSnapshotVersion(t){return R.resolve(this.lastRemoteSnapshotVersion)}getHighestSequenceNumber(t){return R.resolve(this.oi)}allocateTargetId(t){return this.highestTargetId=this.ai.next(),R.resolve(this.highestTargetId)}setTargetsMetadata(t,e,n){return n&&(this.lastRemoteSnapshotVersion=n),e>this.oi&&(this.oi=e),R.resolve()}Pr(t){this.si.set(t.target,t);const e=t.targetId;e>this.highestTargetId&&(this.ai=new ve(e),this.highestTargetId=e),t.sequenceNumber>this.oi&&(this.oi=t.sequenceNumber)}addTargetData(t,e){return this.Pr(e),this.targetCount+=1,R.resolve()}updateTargetData(t,e){return this.Pr(e),R.resolve()}removeTargetData(t,e){return this.si.delete(e.target),this._i.jr(e.targetId),this.targetCount-=1,R.resolve()}removeTargets(t,e,n){let i=0;const o=[];return this.si.forEach((u,l)=>{l.sequenceNumber<=e&&n.get(l.targetId)===null&&(this.si.delete(u),o.push(this.removeMatchingKeysForTargetId(t,l.targetId)),i++)}),R.waitFor(o).next(()=>i)}getTargetCount(t){return R.resolve(this.targetCount)}getTargetData(t,e){const n=this.si.get(e)||null;return R.resolve(n)}addMatchingKeys(t,e,n){return this._i.Wr(e,n),R.resolve()}removeMatchingKeys(t,e,n){this._i.zr(e,n);const i=this.persistence.referenceDelegate,o=[];return i&&e.forEach(u=>{o.push(i.markPotentiallyOrphaned(t,u))}),R.waitFor(o)}removeMatchingKeysForTargetId(t,e){return this._i.jr(e),R.resolve()}getMatchingKeysForTargetId(t,e){const n=this._i.Hr(e);return R.resolve(n)}containsKey(t,e){return R.resolve(this._i.containsKey(e))}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class aa{constructor(t,e){this.ui={},this.overlays={},this.ci=new Qn(0),this.li=!1,this.li=!0,this.hi=new dl,this.referenceDelegate=t(this),this.Pi=new _l(this),this.indexManager=new el,this.remoteDocumentCache=function(i){return new gl(i)}(n=>this.referenceDelegate.Ti(n)),this.serializer=new Zh(e),this.Ii=new cl(this.serializer)}start(){return Promise.resolve()}shutdown(){return this.li=!1,Promise.resolve()}get started(){return this.li}setDatabaseDeletedListener(){}setNetworkEnabled(){}getIndexManager(t){return this.indexManager}getDocumentOverlayCache(t){let e=this.overlays[t.toKey()];return e||(e=new fl,this.overlays[t.toKey()]=e),e}getMutationQueue(t,e){let n=this.ui[t.toKey()];return n||(n=new ml(e,this.referenceDelegate),this.ui[t.toKey()]=n),n}getGlobalsCache(){return this.hi}getTargetCache(){return this.Pi}getRemoteDocumentCache(){return this.remoteDocumentCache}getBundleCache(){return this.Ii}runTransaction(t,e,n){D("MemoryPersistence","Starting transaction:",t);const i=new yl(this.ci.next());return this.referenceDelegate.Ei(),n(i).next(o=>this.referenceDelegate.di(i).next(()=>o)).toPromise().then(o=>(i.raiseOnCommittedEvent(),o))}Ai(t,e){return R.or(Object.values(this.ui).map(n=>()=>n.containsKey(t,e)))}}class yl extends Gu{constructor(t){super(),this.currentSequenceNumber=t}}class hs{constructor(t){this.persistence=t,this.Ri=new us,this.Vi=null}static mi(t){return new hs(t)}get fi(){if(this.Vi)return this.Vi;throw L(60996)}addReference(t,e,n){return this.Ri.addReference(n,e),this.fi.delete(n.toString()),R.resolve()}removeReference(t,e,n){return this.Ri.removeReference(n,e),this.fi.add(n.toString()),R.resolve()}markPotentiallyOrphaned(t,e){return this.fi.add(e.toString()),R.resolve()}removeTarget(t,e){this.Ri.jr(e.targetId).forEach(i=>this.fi.add(i.toString()));const n=this.persistence.getTargetCache();return n.getMatchingKeysForTargetId(t,e.targetId).next(i=>{i.forEach(o=>this.fi.add(o.toString()))}).next(()=>n.removeTargetData(t,e))}Ei(){this.Vi=new Set}di(t){const e=this.persistence.getRemoteDocumentCache().newChangeBuffer();return R.forEach(this.fi,n=>{const i=x.fromPath(n);return this.gi(t,i).next(o=>{o||e.removeEntry(i,O.min())})}).next(()=>(this.Vi=null,e.apply(t)))}updateLimboDocument(t,e){return this.gi(t,e).next(n=>{n?this.fi.delete(e.toString()):this.fi.add(e.toString())})}Ti(t){return 0}gi(t,e){return R.or([()=>R.resolve(this.Ri.containsKey(e)),()=>this.persistence.getTargetCache().containsKey(t,e),()=>this.persistence.Ai(t,e)])}}class Gn{constructor(t,e){this.persistence=t,this.pi=new oe(n=>Qu(n.path),(n,i)=>n.isEqual(i)),this.garbageCollector=al(this,e)}static mi(t,e){return new Gn(t,e)}Ei(){}di(t){return R.resolve()}forEachTarget(t,e){return this.persistence.getTargetCache().forEachTarget(t,e)}gr(t){const e=this.wr(t);return this.persistence.getTargetCache().getTargetCount(t).next(n=>e.next(i=>n+i))}wr(t){let e=0;return this.pr(t,n=>{e++}).next(()=>e)}pr(t,e){return R.forEach(this.pi,(n,i)=>this.br(t,n,i).next(o=>o?R.resolve():e(i)))}removeTargets(t,e,n){return this.persistence.getTargetCache().removeTargets(t,e,n)}removeOrphanedDocuments(t,e){let n=0;const i=this.persistence.getRemoteDocumentCache(),o=i.newChangeBuffer();return i.ii(t,u=>this.br(t,u,e).next(l=>{l||(n++,o.removeEntry(u,O.min()))})).next(()=>o.apply(t)).next(()=>n)}markPotentiallyOrphaned(t,e){return this.pi.set(e,t.currentSequenceNumber),R.resolve()}removeTarget(t,e){const n=e.withSequenceNumber(t.currentSequenceNumber);return this.persistence.getTargetCache().updateTargetData(t,n)}addReference(t,e,n){return this.pi.set(n,t.currentSequenceNumber),R.resolve()}removeReference(t,e,n){return this.pi.set(n,t.currentSequenceNumber),R.resolve()}updateLimboDocument(t,e){return this.pi.set(e,t.currentSequenceNumber),R.resolve()}Ti(t){let e=t.key.toString().length;return t.isFoundDocument()&&(e+=On(t.data.value)),e}br(t,e,n){return R.or([()=>this.persistence.Ai(t,e),()=>this.persistence.getTargetCache().containsKey(t,e),()=>{const i=this.pi.get(e);return R.resolve(i!==void 0&&i>n)}])}getCacheSize(t){return this.persistence.getRemoteDocumentCache().getSize(t)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ls{constructor(t,e,n,i){this.targetId=t,this.fromCache=e,this.Es=n,this.ds=i}static As(t,e){let n=j(),i=j();for(const o of e.docChanges)switch(o.type){case 0:n=n.add(o.doc.key);break;case 1:i=i.add(o.doc.key)}return new ls(t,e.fromCache,n,i)}}/**
 * @license
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class El{constructor(){this._documentReadCount=0}get documentReadCount(){return this._documentReadCount}incrementDocumentReadCount(t){this._documentReadCount+=t}}/**
 * @license
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Tl{constructor(){this.Rs=!1,this.Vs=!1,this.fs=100,this.gs=function(){return Tu()?8:Ku(vu())>0?6:4}()}initialize(t,e){this.ps=t,this.indexManager=e,this.Rs=!0}getDocumentsMatchingQuery(t,e,n,i){const o={result:null};return this.ys(t,e).next(u=>{o.result=u}).next(()=>{if(!o.result)return this.ws(t,e,i,n).next(u=>{o.result=u})}).next(()=>{if(o.result)return;const u=new El;return this.Ss(t,e,u).next(l=>{if(o.result=l,this.Vs)return this.bs(t,e,u,l.size)})}).next(()=>o.result)}bs(t,e,n,i){return n.documentReadCount<this.fs?(ce()<=xt.DEBUG&&D("QueryEngine","SDK will not create cache indexes for query:",fe(e),"since it only creates cache indexes for collection contains","more than or equal to",this.fs,"documents"),R.resolve()):(ce()<=xt.DEBUG&&D("QueryEngine","Query:",fe(e),"scans",n.documentReadCount,"local documents and returns",i,"documents as results."),n.documentReadCount>this.gs*i?(ce()<=xt.DEBUG&&D("QueryEngine","The SDK decides to create cache indexes for query:",fe(e),"as using cache indexes may help improve performance."),this.indexManager.createTargetIndexes(t,St(e))):R.resolve())}ys(t,e){if(ji(e))return R.resolve(null);let n=St(e);return this.indexManager.getIndexType(t,n).next(i=>i===0?null:(e.limit!==null&&i===1&&(e=Br(e,null,"F"),n=St(e)),this.indexManager.getDocumentsMatchingTarget(t,n).next(o=>{const u=j(...o);return this.ps.getDocuments(t,u).next(l=>this.indexManager.getMinOffset(t,n).next(f=>{const d=this.Ds(e,l);return this.Cs(e,d,u,f.readTime)?this.ys(t,Br(e,null,"F")):this.vs(t,d,e,f)}))})))}ws(t,e,n,i){return ji(e)||i.isEqual(O.min())?R.resolve(null):this.ps.getDocuments(t,n).next(o=>{const u=this.Ds(e,o);return this.Cs(e,u,n,i)?R.resolve(null):(ce()<=xt.DEBUG&&D("QueryEngine","Re-using previous result from %s to execute query: %s",i.toString(),fe(e)),this.vs(t,u,e,qu(i,Ze)).next(l=>l))})}Ds(t,e){let n=new rt(zo(t));return e.forEach((i,o)=>{Jn(t,o)&&(n=n.add(o))}),n}Cs(t,e,n,i){if(t.limit===null)return!1;if(n.size!==e.size)return!0;const o=t.limitType==="F"?e.last():e.first();return!!o&&(o.hasPendingWrites||o.version.compareTo(i)>0)}Ss(t,e,n){return ce()<=xt.DEBUG&&D("QueryEngine","Using full collection scan to execute query:",fe(e)),this.ps.getDocumentsMatchingQuery(t,e,Kt.min(),n)}vs(t,e,n,i){return this.ps.getDocumentsMatchingQuery(t,n,i).next(o=>(e.forEach(u=>{o=o.insert(u.key,u)}),o))}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const cs="LocalStore",vl=3e8;class Il{constructor(t,e,n,i){this.persistence=t,this.Fs=e,this.serializer=i,this.Ms=new Y(F),this.xs=new oe(o=>ns(o),rs),this.Os=new Map,this.Ns=t.getRemoteDocumentCache(),this.Pi=t.getTargetCache(),this.Ii=t.getBundleCache(),this.Bs(n)}Bs(t){this.documentOverlayCache=this.persistence.getDocumentOverlayCache(t),this.indexManager=this.persistence.getIndexManager(t),this.mutationQueue=this.persistence.getMutationQueue(t,this.indexManager),this.localDocuments=new ll(this.Ns,this.mutationQueue,this.documentOverlayCache,this.indexManager),this.Ns.setIndexManager(this.indexManager),this.Fs.initialize(this.localDocuments,this.indexManager)}collectGarbage(t){return this.persistence.runTransaction("Collect garbage","readwrite-primary",e=>t.collect(e,this.Ms))}}function Al(s,t,e,n){return new Il(s,t,e,n)}async function ua(s,t){const e=q(s);return await e.persistence.runTransaction("Handle user change","readonly",n=>{let i;return e.mutationQueue.getAllMutationBatches(n).next(o=>(i=o,e.Bs(t),e.mutationQueue.getAllMutationBatches(n))).next(o=>{const u=[],l=[];let f=j();for(const d of i){u.push(d.batchId);for(const _ of d.mutations)f=f.add(_.key)}for(const d of o){l.push(d.batchId);for(const _ of d.mutations)f=f.add(_.key)}return e.localDocuments.getDocuments(n,f).next(d=>({Ls:d,removedBatchIds:u,addedBatchIds:l}))})})}function ha(s){const t=q(s);return t.persistence.runTransaction("Get last remote snapshot version","readonly",e=>t.Pi.getLastRemoteSnapshotVersion(e))}function wl(s,t){const e=q(s),n=t.snapshotVersion;let i=e.Ms;return e.persistence.runTransaction("Apply remote event","readwrite-primary",o=>{const u=e.Ns.newChangeBuffer({trackRemovals:!0});i=e.Ms;const l=[];t.targetChanges.forEach((_,w)=>{const P=i.get(w);if(!P)return;l.push(e.Pi.removeMatchingKeys(o,_.removedDocuments,w).next(()=>e.Pi.addMatchingKeys(o,_.addedDocuments,w)));let C=P.withSequenceNumber(o.currentSequenceNumber);t.targetMismatches.get(w)!==null?C=C.withResumeToken(ht.EMPTY_BYTE_STRING,O.min()).withLastLimboFreeSnapshotVersion(O.min()):_.resumeToken.approximateByteSize()>0&&(C=C.withResumeToken(_.resumeToken,n)),i=i.insert(w,C),function(M,N,et){return M.resumeToken.approximateByteSize()===0||N.snapshotVersion.toMicroseconds()-M.snapshotVersion.toMicroseconds()>=vl?!0:et.addedDocuments.size+et.modifiedDocuments.size+et.removedDocuments.size>0}(P,C,_)&&l.push(e.Pi.updateTargetData(o,C))});let f=Wt(),d=j();if(t.documentUpdates.forEach(_=>{t.resolvedLimboDocuments.has(_)&&l.push(e.persistence.referenceDelegate.updateLimboDocument(o,_))}),l.push(Rl(o,u,t.documentUpdates).next(_=>{f=_.ks,d=_.qs})),!n.isEqual(O.min())){const _=e.Pi.getLastRemoteSnapshotVersion(o).next(w=>e.Pi.setTargetsMetadata(o,o.currentSequenceNumber,n));l.push(_)}return R.waitFor(l).next(()=>u.apply(o)).next(()=>e.localDocuments.getLocalViewOfDocuments(o,f,d)).next(()=>f)}).then(o=>(e.Ms=i,o))}function Rl(s,t,e){let n=j(),i=j();return e.forEach(o=>n=n.add(o)),t.getEntries(s,n).next(o=>{let u=Wt();return e.forEach((l,f)=>{const d=o.get(l);f.isFoundDocument()!==d.isFoundDocument()&&(i=i.add(l)),f.isNoDocument()&&f.version.isEqual(O.min())?(t.removeEntry(l,f.readTime),u=u.insert(l,f)):!d.isValidDocument()||f.version.compareTo(d.version)>0||f.version.compareTo(d.version)===0&&d.hasPendingWrites?(t.addEntry(f),u=u.insert(l,f)):D(cs,"Ignoring outdated watch update for ",l,". Current version:",d.version," Watch version:",f.version)}),{ks:u,qs:i}})}function Pl(s,t){const e=q(s);return e.persistence.runTransaction("Allocate target","readwrite",n=>{let i;return e.Pi.getTargetData(n,t).next(o=>o?(i=o,R.resolve(i)):e.Pi.allocateTargetId(n).next(u=>(i=new jt(t,u,"TargetPurposeListen",n.currentSequenceNumber),e.Pi.addTargetData(n,i).next(()=>i))))}).then(n=>{const i=e.Ms.get(n.targetId);return(i===null||n.snapshotVersion.compareTo(i.snapshotVersion)>0)&&(e.Ms=e.Ms.insert(n.targetId,n),e.xs.set(t,n.targetId)),n})}async function Qr(s,t,e){const n=q(s),i=n.Ms.get(t),o=e?"readwrite":"readwrite-primary";try{e||await n.persistence.runTransaction("Release target",o,u=>n.persistence.referenceDelegate.removeTarget(u,i))}catch(u){if(!Re(u))throw u;D(cs,`Failed to update sequence numbers for target ${t}: ${u}`)}n.Ms=n.Ms.remove(t),n.xs.delete(i.target)}function to(s,t,e){const n=q(s);let i=O.min(),o=j();return n.persistence.runTransaction("Execute query","readwrite",u=>function(f,d,_){const w=q(f),P=w.xs.get(_);return P!==void 0?R.resolve(w.Ms.get(P)):w.Pi.getTargetData(d,_)}(n,u,St(t)).next(l=>{if(l)return i=l.lastLimboFreeSnapshotVersion,n.Pi.getMatchingKeysForTargetId(u,l.targetId).next(f=>{o=f})}).next(()=>n.Fs.getDocumentsMatchingQuery(u,t,e?i:O.min(),e?o:j())).next(l=>(Sl(n,ph(t),l),{documents:l,Qs:o})))}function Sl(s,t,e){let n=s.Os.get(t)||O.min();e.forEach((i,o)=>{o.readTime.compareTo(n)>0&&(n=o.readTime)}),s.Os.set(t,n)}class eo{constructor(){this.activeTargetIds=Ih()}zs(t){this.activeTargetIds=this.activeTargetIds.add(t)}js(t){this.activeTargetIds=this.activeTargetIds.delete(t)}Gs(){const t={activeTargetIds:this.activeTargetIds.toArray(),updateTimeMs:Date.now()};return JSON.stringify(t)}}class Vl{constructor(){this.Mo=new eo,this.xo={},this.onlineStateHandler=null,this.sequenceNumberHandler=null}addPendingMutation(t){}updateMutationState(t,e,n){}addLocalQueryTarget(t,e=!0){return e&&this.Mo.zs(t),this.xo[t]||"not-current"}updateQueryState(t,e,n){this.xo[t]=e}removeLocalQueryTarget(t){this.Mo.js(t)}isLocalQueryTarget(t){return this.Mo.activeTargetIds.has(t)}clearQueryState(t){delete this.xo[t]}getAllActiveQueryTargets(){return this.Mo.activeTargetIds}isActiveQueryTarget(t){return this.Mo.activeTargetIds.has(t)}start(){return this.Mo=new eo,Promise.resolve()}handleUserChange(t,e,n){}setOnlineState(t){}shutdown(){}writeSequenceNumber(t){}notifyBundleLoaded(t){}}/**
 * @license
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Cl{Oo(t){}shutdown(){}}/**
 * @license
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const no="ConnectivityMonitor";class ro{constructor(){this.No=()=>this.Bo(),this.Lo=()=>this.ko(),this.qo=[],this.Qo()}Oo(t){this.qo.push(t)}shutdown(){window.removeEventListener("online",this.No),window.removeEventListener("offline",this.Lo)}Qo(){window.addEventListener("online",this.No),window.addEventListener("offline",this.Lo)}Bo(){D(no,"Network connectivity changed: AVAILABLE");for(const t of this.qo)t(0)}ko(){D(no,"Network connectivity changed: UNAVAILABLE");for(const t of this.qo)t(1)}static v(){return typeof window<"u"&&window.addEventListener!==void 0&&window.removeEventListener!==void 0}}/**
 * @license
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */let bn=null;function Hr(){return bn===null?bn=function(){return 268435456+Math.round(2147483648*Math.random())}():bn++,"0x"+bn.toString(16)}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Dr="RestConnection",Dl={BatchGetDocuments:"batchGet",Commit:"commit",RunQuery:"runQuery",RunAggregationQuery:"runAggregationQuery"};class Nl{get $o(){return!1}constructor(t){this.databaseInfo=t,this.databaseId=t.databaseId;const e=t.ssl?"https":"http",n=encodeURIComponent(this.databaseId.projectId),i=encodeURIComponent(this.databaseId.database);this.Uo=e+"://"+t.host,this.Ko=`projects/${n}/databases/${i}`,this.Wo=this.databaseId.database===Un?`project_id=${n}`:`project_id=${n}&database_id=${i}`}Go(t,e,n,i,o){const u=Hr(),l=this.zo(t,e.toUriEncodedString());D(Dr,`Sending RPC '${t}' ${u}:`,l,n);const f={"google-cloud-resource-prefix":this.Ko,"x-goog-request-params":this.Wo};this.jo(f,i,o);const{host:d}=new URL(l),_=vo(d);return this.Jo(t,l,f,n,_).then(w=>(D(Dr,`Received RPC '${t}' ${u}: `,w),w),w=>{throw _e(Dr,`RPC '${t}' ${u} failed with error: `,w,"url: ",l,"request:",n),w})}Ho(t,e,n,i,o,u){return this.Go(t,e,n,i,o)}jo(t,e,n){t["X-Goog-Api-Client"]=function(){return"gl-js/ fire/"+we}(),t["Content-Type"]="text/plain",this.databaseInfo.appId&&(t["X-Firebase-GMPID"]=this.databaseInfo.appId),e&&e.headers.forEach((i,o)=>t[o]=i),n&&n.headers.forEach((i,o)=>t[o]=i)}zo(t,e){const n=Dl[t];return`${this.Uo}/v1/${e}:${n}`}terminate(){}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class kl{constructor(t){this.Yo=t.Yo,this.Zo=t.Zo}Xo(t){this.e_=t}t_(t){this.n_=t}r_(t){this.i_=t}onMessage(t){this.s_=t}close(){this.Zo()}send(t){this.Yo(t)}o_(){this.e_()}__(){this.n_()}a_(t){this.i_(t)}u_(t){this.s_(t)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const mt="WebChannelConnection";class bl extends Nl{constructor(t){super(t),this.c_=[],this.forceLongPolling=t.forceLongPolling,this.autoDetectLongPolling=t.autoDetectLongPolling,this.useFetchStreams=t.useFetchStreams,this.longPollingOptions=t.longPollingOptions}Jo(t,e,n,i,o){const u=Hr();return new Promise((l,f)=>{const d=new Ao;d.setWithCredentials(!0),d.listenOnce(wo.COMPLETE,()=>{try{switch(d.getLastErrorCode()){case xn.NO_ERROR:const w=d.getResponseJson();D(mt,`XHR for RPC '${t}' ${u} received:`,JSON.stringify(w)),l(w);break;case xn.TIMEOUT:D(mt,`RPC '${t}' ${u} timed out`),f(new k(S.DEADLINE_EXCEEDED,"Request time out"));break;case xn.HTTP_ERROR:const P=d.getStatus();if(D(mt,`RPC '${t}' ${u} failed with status:`,P,"response text:",d.getResponseText()),P>0){let C=d.getResponseJson();Array.isArray(C)&&(C=C[0]);const b=C==null?void 0:C.error;if(b&&b.status&&b.message){const M=function(et){const G=et.toLowerCase().replace(/_/g,"-");return Object.values(S).indexOf(G)>=0?G:S.UNKNOWN}(b.status);f(new k(M,b.message))}else f(new k(S.UNKNOWN,"Server responded with status "+d.getStatus()))}else f(new k(S.UNAVAILABLE,"Connection failed."));break;default:L(9055,{l_:t,streamId:u,h_:d.getLastErrorCode(),P_:d.getLastError()})}}finally{D(mt,`RPC '${t}' ${u} completed.`)}});const _=JSON.stringify(i);D(mt,`RPC '${t}' ${u} sending request:`,i),d.send(e,"POST",_,n,15)})}T_(t,e,n){const i=Hr(),o=[this.Uo,"/","google.firestore.v1.Firestore","/",t,"/channel"],u=So(),l=Po(),f={httpSessionIdParam:"gsessionid",initMessageHeaders:{},messageUrlParams:{database:`projects/${this.databaseId.projectId}/databases/${this.databaseId.database}`},sendRawJson:!0,supportsCrossDomainXhr:!0,internalChannelParams:{forwardChannelRequestTimeoutMs:6e5},forceLongPolling:this.forceLongPolling,detectBufferingProxy:this.autoDetectLongPolling},d=this.longPollingOptions.timeoutSeconds;d!==void 0&&(f.longPollingTimeout=Math.round(1e3*d)),this.useFetchStreams&&(f.useFetchStreams=!0),this.jo(f.initMessageHeaders,e,n),f.encodeInitMessageHeaders=!0;const _=o.join("");D(mt,`Creating RPC '${t}' stream ${i}: ${_}`,f);const w=u.createWebChannel(_,f);this.I_(w);let P=!1,C=!1;const b=new kl({Yo:N=>{C?D(mt,`Not sending because RPC '${t}' stream ${i} is closed:`,N):(P||(D(mt,`Opening RPC '${t}' stream ${i} transport.`),w.open(),P=!0),D(mt,`RPC '${t}' stream ${i} sending:`,N),w.send(N))},Zo:()=>w.close()}),M=(N,et,G)=>{N.listen(et,K=>{try{G(K)}catch(st){setTimeout(()=>{throw st},0)}})};return M(w,Ge.EventType.OPEN,()=>{C||(D(mt,`RPC '${t}' stream ${i} transport opened.`),b.o_())}),M(w,Ge.EventType.CLOSE,()=>{C||(C=!0,D(mt,`RPC '${t}' stream ${i} transport closed`),b.a_(),this.E_(w))}),M(w,Ge.EventType.ERROR,N=>{C||(C=!0,_e(mt,`RPC '${t}' stream ${i} transport errored. Name:`,N.name,"Message:",N.message),b.a_(new k(S.UNAVAILABLE,"The operation could not be completed")))}),M(w,Ge.EventType.MESSAGE,N=>{var et;if(!C){const G=N.data[0];H(!!G,16349);const K=G,st=(K==null?void 0:K.error)||((et=K[0])==null?void 0:et.error);if(st){D(mt,`RPC '${t}' stream ${i} received error:`,st);const Dt=st.status;let ot=function(p){const y=J[p];if(y!==void 0)return Yo(y)}(Dt),T=st.message;ot===void 0&&(ot=S.INTERNAL,T="Unknown error status: "+Dt+" with message "+st.message),C=!0,b.a_(new k(ot,T)),w.close()}else D(mt,`RPC '${t}' stream ${i} received:`,G),b.u_(G)}}),M(l,Ro.STAT_EVENT,N=>{N.stat===br.PROXY?D(mt,`RPC '${t}' stream ${i} detected buffering proxy`):N.stat===br.NOPROXY&&D(mt,`RPC '${t}' stream ${i} detected no buffering proxy`)}),setTimeout(()=>{b.__()},0),b}terminate(){this.c_.forEach(t=>t.close()),this.c_=[]}I_(t){this.c_.push(t)}E_(t){this.c_=this.c_.filter(e=>e===t)}}function Nr(){return typeof document<"u"?document:null}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function la(s){return new qh(s,!0)}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ca{constructor(t,e,n=1e3,i=1.5,o=6e4){this.Mi=t,this.timerId=e,this.d_=n,this.A_=i,this.R_=o,this.V_=0,this.m_=null,this.f_=Date.now(),this.reset()}reset(){this.V_=0}g_(){this.V_=this.R_}p_(t){this.cancel();const e=Math.floor(this.V_+this.y_()),n=Math.max(0,Date.now()-this.f_),i=Math.max(0,e-n);i>0&&D("ExponentialBackoff",`Backing off for ${i} ms (base delay: ${this.V_} ms, delay with jitter: ${e} ms, last attempt: ${n} ms ago)`),this.m_=this.Mi.enqueueAfterDelay(this.timerId,i,()=>(this.f_=Date.now(),t())),this.V_*=this.A_,this.V_<this.d_&&(this.V_=this.d_),this.V_>this.R_&&(this.V_=this.R_)}w_(){this.m_!==null&&(this.m_.skipDelay(),this.m_=null)}cancel(){this.m_!==null&&(this.m_.cancel(),this.m_=null)}y_(){return(Math.random()-.5)*this.V_}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const so="PersistentStream";class xl{constructor(t,e,n,i,o,u,l,f){this.Mi=t,this.S_=n,this.b_=i,this.connection=o,this.authCredentialsProvider=u,this.appCheckCredentialsProvider=l,this.listener=f,this.state=0,this.D_=0,this.C_=null,this.v_=null,this.stream=null,this.F_=0,this.M_=new ca(t,e)}x_(){return this.state===1||this.state===5||this.O_()}O_(){return this.state===2||this.state===3}start(){this.F_=0,this.state!==4?this.auth():this.N_()}async stop(){this.x_()&&await this.close(0)}B_(){this.state=0,this.M_.reset()}L_(){this.O_()&&this.C_===null&&(this.C_=this.Mi.enqueueAfterDelay(this.S_,6e4,()=>this.k_()))}q_(t){this.Q_(),this.stream.send(t)}async k_(){if(this.O_())return this.close(0)}Q_(){this.C_&&(this.C_.cancel(),this.C_=null)}U_(){this.v_&&(this.v_.cancel(),this.v_=null)}async close(t,e){this.Q_(),this.U_(),this.M_.cancel(),this.D_++,t!==4?this.M_.reset():e&&e.code===S.RESOURCE_EXHAUSTED?(Ot(e.toString()),Ot("Using maximum backoff delay to prevent overloading the backend."),this.M_.g_()):e&&e.code===S.UNAUTHENTICATED&&this.state!==3&&(this.authCredentialsProvider.invalidateToken(),this.appCheckCredentialsProvider.invalidateToken()),this.stream!==null&&(this.K_(),this.stream.close(),this.stream=null),this.state=t,await this.listener.r_(e)}K_(){}auth(){this.state=1;const t=this.W_(this.D_),e=this.D_;Promise.all([this.authCredentialsProvider.getToken(),this.appCheckCredentialsProvider.getToken()]).then(([n,i])=>{this.D_===e&&this.G_(n,i)},n=>{t(()=>{const i=new k(S.UNKNOWN,"Fetching auth token failed: "+n.message);return this.z_(i)})})}G_(t,e){const n=this.W_(this.D_);this.stream=this.j_(t,e),this.stream.Xo(()=>{n(()=>this.listener.Xo())}),this.stream.t_(()=>{n(()=>(this.state=2,this.v_=this.Mi.enqueueAfterDelay(this.b_,1e4,()=>(this.O_()&&(this.state=3),Promise.resolve())),this.listener.t_()))}),this.stream.r_(i=>{n(()=>this.z_(i))}),this.stream.onMessage(i=>{n(()=>++this.F_==1?this.J_(i):this.onNext(i))})}N_(){this.state=5,this.M_.p_(async()=>{this.state=0,this.start()})}z_(t){return D(so,`close with error: ${t}`),this.stream=null,this.close(4,t)}W_(t){return e=>{this.Mi.enqueueAndForget(()=>this.D_===t?e():(D(so,"stream callback skipped by getCloseGuardedDispatcher."),Promise.resolve()))}}}class Ol extends xl{constructor(t,e,n,i,o,u){super(t,"listen_stream_connection_backoff","listen_stream_idle","health_check_timeout",e,n,i,u),this.serializer=o}j_(t,e){return this.connection.T_("Listen",t,e)}J_(t){return this.onNext(t)}onNext(t){this.M_.reset();const e=Kh(this.serializer,t),n=function(o){if(!("targetChange"in o))return O.min();const u=o.targetChange;return u.targetIds&&u.targetIds.length?O.min():u.readTime?ge(u.readTime):O.min()}(t);return this.listener.H_(e,n)}Y_(t){const e={};e.database=Xi(this.serializer),e.addTarget=function(o,u){let l;const f=u.target;if(l=jr(f)?{documents:$h(o,f)}:{query:Qh(o,f).ft},l.targetId=u.targetId,u.resumeToken.approximateByteSize()>0){l.resumeToken=Bh(o,u.resumeToken);const d=Kr(o,u.expectedCount);d!==null&&(l.expectedCount=d)}else if(u.snapshotVersion.compareTo(O.min())>0){l.readTime=jh(o,u.snapshotVersion.toTimestamp());const d=Kr(o,u.expectedCount);d!==null&&(l.expectedCount=d)}return l}(this.serializer,t);const n=Wh(this.serializer,t);n&&(e.labels=n),this.q_(e)}Z_(t){const e={};e.database=Xi(this.serializer),e.removeTarget=t,this.q_(e)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Ml{}class Ll extends Ml{constructor(t,e,n,i){super(),this.authCredentials=t,this.appCheckCredentials=e,this.connection=n,this.serializer=i,this.ia=!1}sa(){if(this.ia)throw new k(S.FAILED_PRECONDITION,"The client has already been terminated.")}Go(t,e,n,i){return this.sa(),Promise.all([this.authCredentials.getToken(),this.appCheckCredentials.getToken()]).then(([o,u])=>this.connection.Go(t,$r(e,n),i,o,u)).catch(o=>{throw o.name==="FirebaseError"?(o.code===S.UNAUTHENTICATED&&(this.authCredentials.invalidateToken(),this.appCheckCredentials.invalidateToken()),o):new k(S.UNKNOWN,o.toString())})}Ho(t,e,n,i,o){return this.sa(),Promise.all([this.authCredentials.getToken(),this.appCheckCredentials.getToken()]).then(([u,l])=>this.connection.Ho(t,$r(e,n),i,u,l,o)).catch(u=>{throw u.name==="FirebaseError"?(u.code===S.UNAUTHENTICATED&&(this.authCredentials.invalidateToken(),this.appCheckCredentials.invalidateToken()),u):new k(S.UNKNOWN,u.toString())})}terminate(){this.ia=!0,this.connection.terminate()}}class Fl{constructor(t,e){this.asyncQueue=t,this.onlineStateHandler=e,this.state="Unknown",this.oa=0,this._a=null,this.aa=!0}ua(){this.oa===0&&(this.ca("Unknown"),this._a=this.asyncQueue.enqueueAfterDelay("online_state_timeout",1e4,()=>(this._a=null,this.la("Backend didn't respond within 10 seconds."),this.ca("Offline"),Promise.resolve())))}ha(t){this.state==="Online"?this.ca("Unknown"):(this.oa++,this.oa>=1&&(this.Pa(),this.la(`Connection failed 1 times. Most recent error: ${t.toString()}`),this.ca("Offline")))}set(t){this.Pa(),this.oa=0,t==="Online"&&(this.aa=!1),this.ca(t)}ca(t){t!==this.state&&(this.state=t,this.onlineStateHandler(t))}la(t){const e=`Could not reach Cloud Firestore backend. ${t}
This typically indicates that your device does not have a healthy Internet connection at the moment. The client will operate in offline mode until it is able to successfully connect to the backend.`;this.aa?(Ot(e),this.aa=!1):D("OnlineStateTracker",e)}Pa(){this._a!==null&&(this._a.cancel(),this._a=null)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Ie="RemoteStore";class Ul{constructor(t,e,n,i,o){this.localStore=t,this.datastore=e,this.asyncQueue=n,this.remoteSyncer={},this.Ta=[],this.Ia=new Map,this.Ea=new Set,this.da=[],this.Aa=o,this.Aa.Oo(u=>{n.enqueueAndForget(async()=>{hn(this)&&(D(Ie,"Restarting streams for network reachability change."),await async function(f){const d=q(f);d.Ea.add(4),await un(d),d.Ra.set("Unknown"),d.Ea.delete(4),await nr(d)}(this))})}),this.Ra=new Fl(n,i)}}async function nr(s){if(hn(s))for(const t of s.da)await t(!0)}async function un(s){for(const t of s.da)await t(!1)}function fa(s,t){const e=q(s);e.Ia.has(t.targetId)||(e.Ia.set(t.targetId,t),gs(e)?ms(e):Pe(e).O_()&&ds(e,t))}function fs(s,t){const e=q(s),n=Pe(e);e.Ia.delete(t),n.O_()&&da(e,t),e.Ia.size===0&&(n.O_()?n.L_():hn(e)&&e.Ra.set("Unknown"))}function ds(s,t){if(s.Va.Ue(t.targetId),t.resumeToken.approximateByteSize()>0||t.snapshotVersion.compareTo(O.min())>0){const e=s.remoteSyncer.getRemoteKeysForTarget(t.targetId).size;t=t.withExpectedCount(e)}Pe(s).Y_(t)}function da(s,t){s.Va.Ue(t),Pe(s).Z_(t)}function ms(s){s.Va=new Mh({getRemoteKeysForTarget:t=>s.remoteSyncer.getRemoteKeysForTarget(t),At:t=>s.Ia.get(t)||null,ht:()=>s.datastore.serializer.databaseId}),Pe(s).start(),s.Ra.ua()}function gs(s){return hn(s)&&!Pe(s).x_()&&s.Ia.size>0}function hn(s){return q(s).Ea.size===0}function ma(s){s.Va=void 0}async function ql(s){s.Ra.set("Online")}async function jl(s){s.Ia.forEach((t,e)=>{ds(s,t)})}async function Bl(s,t){ma(s),gs(s)?(s.Ra.ha(t),ms(s)):s.Ra.set("Unknown")}async function zl(s,t,e){if(s.Ra.set("Online"),t instanceof Zo&&t.state===2&&t.cause)try{await async function(i,o){const u=o.cause;for(const l of o.targetIds)i.Ia.has(l)&&(await i.remoteSyncer.rejectListen(l,u),i.Ia.delete(l),i.Va.removeTarget(l))}(s,t)}catch(n){D(Ie,"Failed to remove targets %s: %s ",t.targetIds.join(","),n),await io(s,n)}else if(t instanceof Ln?s.Va.Ze(t):t instanceof Jo?s.Va.st(t):s.Va.tt(t),!e.isEqual(O.min()))try{const n=await ha(s.localStore);e.compareTo(n)>=0&&await function(o,u){const l=o.Va.Tt(u);return l.targetChanges.forEach((f,d)=>{if(f.resumeToken.approximateByteSize()>0){const _=o.Ia.get(d);_&&o.Ia.set(d,_.withResumeToken(f.resumeToken,u))}}),l.targetMismatches.forEach((f,d)=>{const _=o.Ia.get(f);if(!_)return;o.Ia.set(f,_.withResumeToken(ht.EMPTY_BYTE_STRING,_.snapshotVersion)),da(o,f);const w=new jt(_.target,f,d,_.sequenceNumber);ds(o,w)}),o.remoteSyncer.applyRemoteEvent(l)}(s,e)}catch(n){D(Ie,"Failed to raise snapshot:",n),await io(s,n)}}async function io(s,t,e){if(!Re(t))throw t;s.Ea.add(1),await un(s),s.Ra.set("Offline"),e||(e=()=>ha(s.localStore)),s.asyncQueue.enqueueRetryable(async()=>{D(Ie,"Retrying IndexedDB access"),await e(),s.Ea.delete(1),await nr(s)})}async function oo(s,t){const e=q(s);e.asyncQueue.verifyOperationInProgress(),D(Ie,"RemoteStore received new credentials");const n=hn(e);e.Ea.add(3),await un(e),n&&e.Ra.set("Unknown"),await e.remoteSyncer.handleCredentialChange(t),e.Ea.delete(3),await nr(e)}async function Gl(s,t){const e=q(s);t?(e.Ea.delete(2),await nr(e)):t||(e.Ea.add(2),await un(e),e.Ra.set("Unknown"))}function Pe(s){return s.ma||(s.ma=function(e,n,i){const o=q(e);return o.sa(),new Ol(n,o.connection,o.authCredentials,o.appCheckCredentials,o.serializer,i)}(s.datastore,s.asyncQueue,{Xo:ql.bind(null,s),t_:jl.bind(null,s),r_:Bl.bind(null,s),H_:zl.bind(null,s)}),s.da.push(async t=>{t?(s.ma.B_(),gs(s)?ms(s):s.Ra.set("Unknown")):(await s.ma.stop(),ma(s))})),s.ma}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ps{constructor(t,e,n,i,o){this.asyncQueue=t,this.timerId=e,this.targetTimeMs=n,this.op=i,this.removalCallback=o,this.deferred=new ne,this.then=this.deferred.promise.then.bind(this.deferred.promise),this.deferred.promise.catch(u=>{})}get promise(){return this.deferred.promise}static createAndSchedule(t,e,n,i,o){const u=Date.now()+n,l=new ps(t,e,u,i,o);return l.start(n),l}start(t){this.timerHandle=setTimeout(()=>this.handleDelayElapsed(),t)}skipDelay(){return this.handleDelayElapsed()}cancel(t){this.timerHandle!==null&&(this.clearTimeout(),this.deferred.reject(new k(S.CANCELLED,"Operation cancelled"+(t?": "+t:""))))}handleDelayElapsed(){this.asyncQueue.enqueueAndForget(()=>this.timerHandle!==null?(this.clearTimeout(),this.op().then(t=>this.deferred.resolve(t))):Promise.resolve())}clearTimeout(){this.timerHandle!==null&&(this.removalCallback(this),clearTimeout(this.timerHandle),this.timerHandle=null)}}function ga(s,t){if(Ot("AsyncQueue",`${t}: ${s}`),Re(s))return new k(S.UNAVAILABLE,`${t}: ${s}`);throw s}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class pe{static emptySet(t){return new pe(t.comparator)}constructor(t){this.comparator=t?(e,n)=>t(e,n)||x.comparator(e.key,n.key):(e,n)=>x.comparator(e.key,n.key),this.keyedMap=Ke(),this.sortedSet=new Y(this.comparator)}has(t){return this.keyedMap.get(t)!=null}get(t){return this.keyedMap.get(t)}first(){return this.sortedSet.minKey()}last(){return this.sortedSet.maxKey()}isEmpty(){return this.sortedSet.isEmpty()}indexOf(t){const e=this.keyedMap.get(t);return e?this.sortedSet.indexOf(e):-1}get size(){return this.sortedSet.size}forEach(t){this.sortedSet.inorderTraversal((e,n)=>(t(e),!1))}add(t){const e=this.delete(t.key);return e.copy(e.keyedMap.insert(t.key,t),e.sortedSet.insert(t,null))}delete(t){const e=this.get(t);return e?this.copy(this.keyedMap.remove(t),this.sortedSet.remove(e)):this}isEqual(t){if(!(t instanceof pe)||this.size!==t.size)return!1;const e=this.sortedSet.getIterator(),n=t.sortedSet.getIterator();for(;e.hasNext();){const i=e.getNext().key,o=n.getNext().key;if(!i.isEqual(o))return!1}return!0}toString(){const t=[];return this.forEach(e=>{t.push(e.toString())}),t.length===0?"DocumentSet ()":`DocumentSet (
  `+t.join(`  
`)+`
)`}copy(t,e){const n=new pe;return n.comparator=this.comparator,n.keyedMap=t,n.sortedSet=e,n}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class ao{constructor(){this.ga=new Y(x.comparator)}track(t){const e=t.doc.key,n=this.ga.get(e);n?t.type!==0&&n.type===3?this.ga=this.ga.insert(e,t):t.type===3&&n.type!==1?this.ga=this.ga.insert(e,{type:n.type,doc:t.doc}):t.type===2&&n.type===2?this.ga=this.ga.insert(e,{type:2,doc:t.doc}):t.type===2&&n.type===0?this.ga=this.ga.insert(e,{type:0,doc:t.doc}):t.type===1&&n.type===0?this.ga=this.ga.remove(e):t.type===1&&n.type===2?this.ga=this.ga.insert(e,{type:1,doc:n.doc}):t.type===0&&n.type===1?this.ga=this.ga.insert(e,{type:2,doc:t.doc}):L(63341,{Rt:t,pa:n}):this.ga=this.ga.insert(e,t)}ya(){const t=[];return this.ga.inorderTraversal((e,n)=>{t.push(n)}),t}}class Ae{constructor(t,e,n,i,o,u,l,f,d){this.query=t,this.docs=e,this.oldDocs=n,this.docChanges=i,this.mutatedKeys=o,this.fromCache=u,this.syncStateChanged=l,this.excludesMetadataChanges=f,this.hasCachedResults=d}static fromInitialDocuments(t,e,n,i,o){const u=[];return e.forEach(l=>{u.push({type:0,doc:l})}),new Ae(t,e,pe.emptySet(e),u,n,i,!0,!1,o)}get hasPendingWrites(){return!this.mutatedKeys.isEmpty()}isEqual(t){if(!(this.fromCache===t.fromCache&&this.hasCachedResults===t.hasCachedResults&&this.syncStateChanged===t.syncStateChanged&&this.mutatedKeys.isEqual(t.mutatedKeys)&&Yn(this.query,t.query)&&this.docs.isEqual(t.docs)&&this.oldDocs.isEqual(t.oldDocs)))return!1;const e=this.docChanges,n=t.docChanges;if(e.length!==n.length)return!1;for(let i=0;i<e.length;i++)if(e[i].type!==n[i].type||!e[i].doc.isEqual(n[i].doc))return!1;return!0}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Kl{constructor(){this.wa=void 0,this.Sa=[]}ba(){return this.Sa.some(t=>t.Da())}}class $l{constructor(){this.queries=uo(),this.onlineState="Unknown",this.Ca=new Set}terminate(){(function(e,n){const i=q(e),o=i.queries;i.queries=uo(),o.forEach((u,l)=>{for(const f of l.Sa)f.onError(n)})})(this,new k(S.ABORTED,"Firestore shutting down"))}}function uo(){return new oe(s=>Bo(s),Yn)}async function Ql(s,t){const e=q(s);let n=3;const i=t.query;let o=e.queries.get(i);o?!o.ba()&&t.Da()&&(n=2):(o=new Kl,n=t.Da()?0:1);try{switch(n){case 0:o.wa=await e.onListen(i,!0);break;case 1:o.wa=await e.onListen(i,!1);break;case 2:await e.onFirstRemoteStoreListen(i)}}catch(u){const l=ga(u,`Initialization of query '${fe(t.query)}' failed`);return void t.onError(l)}e.queries.set(i,o),o.Sa.push(t),t.va(e.onlineState),o.wa&&t.Fa(o.wa)&&_s(e)}async function Hl(s,t){const e=q(s),n=t.query;let i=3;const o=e.queries.get(n);if(o){const u=o.Sa.indexOf(t);u>=0&&(o.Sa.splice(u,1),o.Sa.length===0?i=t.Da()?0:1:!o.ba()&&t.Da()&&(i=2))}switch(i){case 0:return e.queries.delete(n),e.onUnlisten(n,!0);case 1:return e.queries.delete(n),e.onUnlisten(n,!1);case 2:return e.onLastRemoteStoreUnlisten(n);default:return}}function Wl(s,t){const e=q(s);let n=!1;for(const i of t){const o=i.query,u=e.queries.get(o);if(u){for(const l of u.Sa)l.Fa(i)&&(n=!0);u.wa=i}}n&&_s(e)}function Xl(s,t,e){const n=q(s),i=n.queries.get(t);if(i)for(const o of i.Sa)o.onError(e);n.queries.delete(t)}function _s(s){s.Ca.forEach(t=>{t.next()})}var Wr,ho;(ho=Wr||(Wr={})).Ma="default",ho.Cache="cache";class Yl{constructor(t,e,n){this.query=t,this.xa=e,this.Oa=!1,this.Na=null,this.onlineState="Unknown",this.options=n||{}}Fa(t){if(!this.options.includeMetadataChanges){const n=[];for(const i of t.docChanges)i.type!==3&&n.push(i);t=new Ae(t.query,t.docs,t.oldDocs,n,t.mutatedKeys,t.fromCache,t.syncStateChanged,!0,t.hasCachedResults)}let e=!1;return this.Oa?this.Ba(t)&&(this.xa.next(t),e=!0):this.La(t,this.onlineState)&&(this.ka(t),e=!0),this.Na=t,e}onError(t){this.xa.error(t)}va(t){this.onlineState=t;let e=!1;return this.Na&&!this.Oa&&this.La(this.Na,t)&&(this.ka(this.Na),e=!0),e}La(t,e){if(!t.fromCache||!this.Da())return!0;const n=e!=="Offline";return(!this.options.qa||!n)&&(!t.docs.isEmpty()||t.hasCachedResults||e==="Offline")}Ba(t){if(t.docChanges.length>0)return!0;const e=this.Na&&this.Na.hasPendingWrites!==t.hasPendingWrites;return!(!t.syncStateChanged&&!e)&&this.options.includeMetadataChanges===!0}ka(t){t=Ae.fromInitialDocuments(t.query,t.docs,t.mutatedKeys,t.fromCache,t.hasCachedResults),this.Oa=!0,this.xa.next(t)}Da(){return this.options.source!==Wr.Cache}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class pa{constructor(t){this.key=t}}class _a{constructor(t){this.key=t}}class Jl{constructor(t,e){this.query=t,this.Ya=e,this.Za=null,this.hasCachedResults=!1,this.current=!1,this.Xa=j(),this.mutatedKeys=j(),this.eu=zo(t),this.tu=new pe(this.eu)}get nu(){return this.Ya}ru(t,e){const n=e?e.iu:new ao,i=e?e.tu:this.tu;let o=e?e.mutatedKeys:this.mutatedKeys,u=i,l=!1;const f=this.query.limitType==="F"&&i.size===this.query.limit?i.last():null,d=this.query.limitType==="L"&&i.size===this.query.limit?i.first():null;if(t.inorderTraversal((_,w)=>{const P=i.get(_),C=Jn(this.query,w)?w:null,b=!!P&&this.mutatedKeys.has(P.key),M=!!C&&(C.hasLocalMutations||this.mutatedKeys.has(C.key)&&C.hasCommittedMutations);let N=!1;P&&C?P.data.isEqual(C.data)?b!==M&&(n.track({type:3,doc:C}),N=!0):this.su(P,C)||(n.track({type:2,doc:C}),N=!0,(f&&this.eu(C,f)>0||d&&this.eu(C,d)<0)&&(l=!0)):!P&&C?(n.track({type:0,doc:C}),N=!0):P&&!C&&(n.track({type:1,doc:P}),N=!0,(f||d)&&(l=!0)),N&&(C?(u=u.add(C),o=M?o.add(_):o.delete(_)):(u=u.delete(_),o=o.delete(_)))}),this.query.limit!==null)for(;u.size>this.query.limit;){const _=this.query.limitType==="F"?u.last():u.first();u=u.delete(_.key),o=o.delete(_.key),n.track({type:1,doc:_})}return{tu:u,iu:n,Cs:l,mutatedKeys:o}}su(t,e){return t.hasLocalMutations&&e.hasCommittedMutations&&!e.hasLocalMutations}applyChanges(t,e,n,i){const o=this.tu;this.tu=t.tu,this.mutatedKeys=t.mutatedKeys;const u=t.iu.ya();u.sort((_,w)=>function(C,b){const M=N=>{switch(N){case 0:return 1;case 2:case 3:return 2;case 1:return 0;default:return L(20277,{Rt:N})}};return M(C)-M(b)}(_.type,w.type)||this.eu(_.doc,w.doc)),this.ou(n),i=i??!1;const l=e&&!i?this._u():[],f=this.Xa.size===0&&this.current&&!i?1:0,d=f!==this.Za;return this.Za=f,u.length!==0||d?{snapshot:new Ae(this.query,t.tu,o,u,t.mutatedKeys,f===0,d,!1,!!n&&n.resumeToken.approximateByteSize()>0),au:l}:{au:l}}va(t){return this.current&&t==="Offline"?(this.current=!1,this.applyChanges({tu:this.tu,iu:new ao,mutatedKeys:this.mutatedKeys,Cs:!1},!1)):{au:[]}}uu(t){return!this.Ya.has(t)&&!!this.tu.has(t)&&!this.tu.get(t).hasLocalMutations}ou(t){t&&(t.addedDocuments.forEach(e=>this.Ya=this.Ya.add(e)),t.modifiedDocuments.forEach(e=>{}),t.removedDocuments.forEach(e=>this.Ya=this.Ya.delete(e)),this.current=t.current)}_u(){if(!this.current)return[];const t=this.Xa;this.Xa=j(),this.tu.forEach(n=>{this.uu(n.key)&&(this.Xa=this.Xa.add(n.key))});const e=[];return t.forEach(n=>{this.Xa.has(n)||e.push(new _a(n))}),this.Xa.forEach(n=>{t.has(n)||e.push(new pa(n))}),e}cu(t){this.Ya=t.Qs,this.Xa=j();const e=this.ru(t.documents);return this.applyChanges(e,!0)}lu(){return Ae.fromInitialDocuments(this.query,this.tu,this.mutatedKeys,this.Za===0,this.hasCachedResults)}}const ys="SyncEngine";class Zl{constructor(t,e,n){this.query=t,this.targetId=e,this.view=n}}class tc{constructor(t){this.key=t,this.hu=!1}}class ec{constructor(t,e,n,i,o,u){this.localStore=t,this.remoteStore=e,this.eventManager=n,this.sharedClientState=i,this.currentUser=o,this.maxConcurrentLimboResolutions=u,this.Pu={},this.Tu=new oe(l=>Bo(l),Yn),this.Iu=new Map,this.Eu=new Set,this.du=new Y(x.comparator),this.Au=new Map,this.Ru=new us,this.Vu={},this.mu=new Map,this.fu=ve.cr(),this.onlineState="Unknown",this.gu=void 0}get isPrimaryClient(){return this.gu===!0}}async function nc(s,t,e=!0){const n=Ia(s);let i;const o=n.Tu.get(t);return o?(n.sharedClientState.addLocalQueryTarget(o.targetId),i=o.view.lu()):i=await ya(n,t,e,!0),i}async function rc(s,t){const e=Ia(s);await ya(e,t,!0,!1)}async function ya(s,t,e,n){const i=await Pl(s.localStore,St(t)),o=i.targetId,u=s.sharedClientState.addLocalQueryTarget(o,e);let l;return n&&(l=await sc(s,t,o,u==="current",i.resumeToken)),s.isPrimaryClient&&e&&fa(s.remoteStore,i),l}async function sc(s,t,e,n,i){s.pu=(w,P,C)=>async function(M,N,et,G){let K=N.view.ru(et);K.Cs&&(K=await to(M.localStore,N.query,!1).then(({documents:T})=>N.view.ru(T,K)));const st=G&&G.targetChanges.get(N.targetId),Dt=G&&G.targetMismatches.get(N.targetId)!=null,ot=N.view.applyChanges(K,M.isPrimaryClient,st,Dt);return co(M,N.targetId,ot.au),ot.snapshot}(s,w,P,C);const o=await to(s.localStore,t,!0),u=new Jl(t,o.Qs),l=u.ru(o.documents),f=an.createSynthesizedTargetChangeForCurrentChange(e,n&&s.onlineState!=="Offline",i),d=u.applyChanges(l,s.isPrimaryClient,f);co(s,e,d.au);const _=new Zl(t,e,u);return s.Tu.set(t,_),s.Iu.has(e)?s.Iu.get(e).push(t):s.Iu.set(e,[t]),d.snapshot}async function ic(s,t,e){const n=q(s),i=n.Tu.get(t),o=n.Iu.get(i.targetId);if(o.length>1)return n.Iu.set(i.targetId,o.filter(u=>!Yn(u,t))),void n.Tu.delete(t);n.isPrimaryClient?(n.sharedClientState.removeLocalQueryTarget(i.targetId),n.sharedClientState.isActiveQueryTarget(i.targetId)||await Qr(n.localStore,i.targetId,!1).then(()=>{n.sharedClientState.clearQueryState(i.targetId),e&&fs(n.remoteStore,i.targetId),Xr(n,i.targetId)}).catch($n)):(Xr(n,i.targetId),await Qr(n.localStore,i.targetId,!0))}async function oc(s,t){const e=q(s),n=e.Tu.get(t),i=e.Iu.get(n.targetId);e.isPrimaryClient&&i.length===1&&(e.sharedClientState.removeLocalQueryTarget(n.targetId),fs(e.remoteStore,n.targetId))}async function Ea(s,t){const e=q(s);try{const n=await wl(e.localStore,t);t.targetChanges.forEach((i,o)=>{const u=e.Au.get(o);u&&(H(i.addedDocuments.size+i.modifiedDocuments.size+i.removedDocuments.size<=1,22616),i.addedDocuments.size>0?u.hu=!0:i.modifiedDocuments.size>0?H(u.hu,14607):i.removedDocuments.size>0&&(H(u.hu,42227),u.hu=!1))}),await va(e,n,t)}catch(n){await $n(n)}}function lo(s,t,e){const n=q(s);if(n.isPrimaryClient&&e===0||!n.isPrimaryClient&&e===1){const i=[];n.Tu.forEach((o,u)=>{const l=u.view.va(t);l.snapshot&&i.push(l.snapshot)}),function(u,l){const f=q(u);f.onlineState=l;let d=!1;f.queries.forEach((_,w)=>{for(const P of w.Sa)P.va(l)&&(d=!0)}),d&&_s(f)}(n.eventManager,t),i.length&&n.Pu.H_(i),n.onlineState=t,n.isPrimaryClient&&n.sharedClientState.setOnlineState(t)}}async function ac(s,t,e){const n=q(s);n.sharedClientState.updateQueryState(t,"rejected",e);const i=n.Au.get(t),o=i&&i.key;if(o){let u=new Y(x.comparator);u=u.insert(o,pt.newNoDocument(o,O.min()));const l=j().add(o),f=new er(O.min(),new Map,new Y(F),u,l);await Ea(n,f),n.du=n.du.remove(o),n.Au.delete(t),Es(n)}else await Qr(n.localStore,t,!1).then(()=>Xr(n,t,e)).catch($n)}function Xr(s,t,e=null){s.sharedClientState.removeLocalQueryTarget(t);for(const n of s.Iu.get(t))s.Tu.delete(n),e&&s.Pu.yu(n,e);s.Iu.delete(t),s.isPrimaryClient&&s.Ru.jr(t).forEach(n=>{s.Ru.containsKey(n)||Ta(s,n)})}function Ta(s,t){s.Eu.delete(t.path.canonicalString());const e=s.du.get(t);e!==null&&(fs(s.remoteStore,e),s.du=s.du.remove(t),s.Au.delete(e),Es(s))}function co(s,t,e){for(const n of e)n instanceof pa?(s.Ru.addReference(n.key,t),uc(s,n)):n instanceof _a?(D(ys,"Document no longer in limbo: "+n.key),s.Ru.removeReference(n.key,t),s.Ru.containsKey(n.key)||Ta(s,n.key)):L(19791,{wu:n})}function uc(s,t){const e=t.key,n=e.path.canonicalString();s.du.get(e)||s.Eu.has(n)||(D(ys,"New document in limbo: "+e),s.Eu.add(n),Es(s))}function Es(s){for(;s.Eu.size>0&&s.du.size<s.maxConcurrentLimboResolutions;){const t=s.Eu.values().next().value;s.Eu.delete(t);const e=new x(Q.fromString(t)),n=s.fu.next();s.Au.set(n,new tc(e)),s.du=s.du.insert(e,n),fa(s.remoteStore,new jt(St(ss(e.path)),n,"TargetPurposeLimboResolution",Qn.ce))}}async function va(s,t,e){const n=q(s),i=[],o=[],u=[];n.Tu.isEmpty()||(n.Tu.forEach((l,f)=>{u.push(n.pu(f,t,e).then(d=>{var _;if((d||e)&&n.isPrimaryClient){const w=d?!d.fromCache:(_=e==null?void 0:e.targetChanges.get(f.targetId))==null?void 0:_.current;n.sharedClientState.updateQueryState(f.targetId,w?"current":"not-current")}if(d){i.push(d);const w=ls.As(f.targetId,d);o.push(w)}}))}),await Promise.all(u),n.Pu.H_(i),await async function(f,d){const _=q(f);try{await _.persistence.runTransaction("notifyLocalViewChanges","readwrite",w=>R.forEach(d,P=>R.forEach(P.Es,C=>_.persistence.referenceDelegate.addReference(w,P.targetId,C)).next(()=>R.forEach(P.ds,C=>_.persistence.referenceDelegate.removeReference(w,P.targetId,C)))))}catch(w){if(!Re(w))throw w;D(cs,"Failed to update sequence numbers: "+w)}for(const w of d){const P=w.targetId;if(!w.fromCache){const C=_.Ms.get(P),b=C.snapshotVersion,M=C.withLastLimboFreeSnapshotVersion(b);_.Ms=_.Ms.insert(P,M)}}}(n.localStore,o))}async function hc(s,t){const e=q(s);if(!e.currentUser.isEqual(t)){D(ys,"User change. New user:",t.toKey());const n=await ua(e.localStore,t);e.currentUser=t,function(o,u){o.mu.forEach(l=>{l.forEach(f=>{f.reject(new k(S.CANCELLED,u))})}),o.mu.clear()}(e,"'waitForPendingWrites' promise is rejected due to a user change."),e.sharedClientState.handleUserChange(t,n.removedBatchIds,n.addedBatchIds),await va(e,n.Ls)}}function lc(s,t){const e=q(s),n=e.Au.get(t);if(n&&n.hu)return j().add(n.key);{let i=j();const o=e.Iu.get(t);if(!o)return i;for(const u of o){const l=e.Tu.get(u);i=i.unionWith(l.view.nu)}return i}}function Ia(s){const t=q(s);return t.remoteStore.remoteSyncer.applyRemoteEvent=Ea.bind(null,t),t.remoteStore.remoteSyncer.getRemoteKeysForTarget=lc.bind(null,t),t.remoteStore.remoteSyncer.rejectListen=ac.bind(null,t),t.Pu.H_=Wl.bind(null,t.eventManager),t.Pu.yu=Xl.bind(null,t.eventManager),t}class Kn{constructor(){this.kind="memory",this.synchronizeTabs=!1}async initialize(t){this.serializer=la(t.databaseInfo.databaseId),this.sharedClientState=this.Du(t),this.persistence=this.Cu(t),await this.persistence.start(),this.localStore=this.vu(t),this.gcScheduler=this.Fu(t,this.localStore),this.indexBackfillerScheduler=this.Mu(t,this.localStore)}Fu(t,e){return null}Mu(t,e){return null}vu(t){return Al(this.persistence,new Tl,t.initialUser,this.serializer)}Cu(t){return new aa(hs.mi,this.serializer)}Du(t){return new Vl}async terminate(){var t,e;(t=this.gcScheduler)==null||t.stop(),(e=this.indexBackfillerScheduler)==null||e.stop(),this.sharedClientState.shutdown(),await this.persistence.shutdown()}}Kn.provider={build:()=>new Kn};class cc extends Kn{constructor(t){super(),this.cacheSizeBytes=t}Fu(t,e){H(this.persistence.referenceDelegate instanceof Gn,46915);const n=this.persistence.referenceDelegate.garbageCollector;return new il(n,t.asyncQueue,e)}Cu(t){const e=this.cacheSizeBytes!==void 0?vt.withCacheSize(this.cacheSizeBytes):vt.DEFAULT;return new aa(n=>Gn.mi(n,e),this.serializer)}}class Yr{async initialize(t,e){this.localStore||(this.localStore=t.localStore,this.sharedClientState=t.sharedClientState,this.datastore=this.createDatastore(e),this.remoteStore=this.createRemoteStore(e),this.eventManager=this.createEventManager(e),this.syncEngine=this.createSyncEngine(e,!t.synchronizeTabs),this.sharedClientState.onlineStateHandler=n=>lo(this.syncEngine,n,1),this.remoteStore.remoteSyncer.handleCredentialChange=hc.bind(null,this.syncEngine),await Gl(this.remoteStore,this.syncEngine.isPrimaryClient))}createEventManager(t){return function(){return new $l}()}createDatastore(t){const e=la(t.databaseInfo.databaseId),n=function(o){return new bl(o)}(t.databaseInfo);return function(o,u,l,f){return new Ll(o,u,l,f)}(t.authCredentials,t.appCheckCredentials,n,e)}createRemoteStore(t){return function(n,i,o,u,l){return new Ul(n,i,o,u,l)}(this.localStore,this.datastore,t.asyncQueue,e=>lo(this.syncEngine,e,0),function(){return ro.v()?new ro:new Cl}())}createSyncEngine(t,e){return function(i,o,u,l,f,d,_){const w=new ec(i,o,u,l,f,d);return _&&(w.gu=!0),w}(this.localStore,this.remoteStore,this.eventManager,this.sharedClientState,t.initialUser,t.maxConcurrentLimboResolutions,e)}async terminate(){var t,e;await async function(i){const o=q(i);D(Ie,"RemoteStore shutting down."),o.Ea.add(5),await un(o),o.Aa.shutdown(),o.Ra.set("Unknown")}(this.remoteStore),(t=this.datastore)==null||t.terminate(),(e=this.eventManager)==null||e.terminate()}}Yr.provider={build:()=>new Yr};/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *//**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class fc{constructor(t){this.observer=t,this.muted=!1}next(t){this.muted||this.observer.next&&this.Ou(this.observer.next,t)}error(t){this.muted||(this.observer.error?this.Ou(this.observer.error,t):Ot("Uncaught Error in snapshot listener:",t.toString()))}Nu(){this.muted=!0}Ou(t,e){setTimeout(()=>{this.muted||t(e)},0)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const Xt="FirestoreClient";class dc{constructor(t,e,n,i,o){this.authCredentials=t,this.appCheckCredentials=e,this.asyncQueue=n,this.databaseInfo=i,this.user=gt.UNAUTHENTICATED,this.clientId=Zr.newId(),this.authCredentialListener=()=>Promise.resolve(),this.appCheckCredentialListener=()=>Promise.resolve(),this._uninitializedComponentsProvider=o,this.authCredentials.start(n,async u=>{D(Xt,"Received user=",u.uid),await this.authCredentialListener(u),this.user=u}),this.appCheckCredentials.start(n,u=>(D(Xt,"Received new app check token=",u),this.appCheckCredentialListener(u,this.user)))}get configuration(){return{asyncQueue:this.asyncQueue,databaseInfo:this.databaseInfo,clientId:this.clientId,authCredentials:this.authCredentials,appCheckCredentials:this.appCheckCredentials,initialUser:this.user,maxConcurrentLimboResolutions:100}}setCredentialChangeListener(t){this.authCredentialListener=t}setAppCheckTokenChangeListener(t){this.appCheckCredentialListener=t}terminate(){this.asyncQueue.enterRestrictedMode();const t=new ne;return this.asyncQueue.enqueueAndForgetEvenWhileRestricted(async()=>{try{this._onlineComponents&&await this._onlineComponents.terminate(),this._offlineComponents&&await this._offlineComponents.terminate(),this.authCredentials.shutdown(),this.appCheckCredentials.shutdown(),t.resolve()}catch(e){const n=ga(e,"Failed to shutdown persistence");t.reject(n)}}),t.promise}}async function kr(s,t){s.asyncQueue.verifyOperationInProgress(),D(Xt,"Initializing OfflineComponentProvider");const e=s.configuration;await t.initialize(e);let n=e.initialUser;s.setCredentialChangeListener(async i=>{n.isEqual(i)||(await ua(t.localStore,i),n=i)}),t.persistence.setDatabaseDeletedListener(()=>s.terminate()),s._offlineComponents=t}async function fo(s,t){s.asyncQueue.verifyOperationInProgress();const e=await mc(s);D(Xt,"Initializing OnlineComponentProvider"),await t.initialize(e,s.configuration),s.setCredentialChangeListener(n=>oo(t.remoteStore,n)),s.setAppCheckTokenChangeListener((n,i)=>oo(t.remoteStore,i)),s._onlineComponents=t}async function mc(s){if(!s._offlineComponents)if(s._uninitializedComponentsProvider){D(Xt,"Using user provided OfflineComponentProvider");try{await kr(s,s._uninitializedComponentsProvider._offline)}catch(t){const e=t;if(!function(i){return i.name==="FirebaseError"?i.code===S.FAILED_PRECONDITION||i.code===S.UNIMPLEMENTED:!(typeof DOMException<"u"&&i instanceof DOMException)||i.code===22||i.code===20||i.code===11}(e))throw e;_e("Error using user provided cache. Falling back to memory cache: "+e),await kr(s,new Kn)}}else D(Xt,"Using default OfflineComponentProvider"),await kr(s,new cc(void 0));return s._offlineComponents}async function gc(s){return s._onlineComponents||(s._uninitializedComponentsProvider?(D(Xt,"Using user provided OnlineComponentProvider"),await fo(s,s._uninitializedComponentsProvider._online)):(D(Xt,"Using default OnlineComponentProvider"),await fo(s,new Yr))),s._onlineComponents}async function pc(s){const t=await gc(s),e=t.eventManager;return e.onListen=nc.bind(null,t.syncEngine),e.onUnlisten=ic.bind(null,t.syncEngine),e.onFirstRemoteStoreListen=rc.bind(null,t.syncEngine),e.onLastRemoteStoreUnlisten=oc.bind(null,t.syncEngine),e}function _c(s,t,e={}){const n=new ne;return s.asyncQueue.enqueueAndForget(async()=>function(o,u,l,f,d){const _=new fc({next:P=>{_.Nu(),u.enqueueAndForget(()=>Hl(o,w));const C=P.docs.has(l);!C&&P.fromCache?d.reject(new k(S.UNAVAILABLE,"Failed to get document because the client is offline.")):C&&P.fromCache&&f&&f.source==="server"?d.reject(new k(S.UNAVAILABLE,'Failed to get document from server. (However, this document does exist in the local cache. Run again without setting source to "server" to retrieve the cached document.)')):d.resolve(P)},error:P=>d.reject(P)}),w=new Yl(ss(l.path),_,{includeMetadataChanges:!0,qa:!0});return Ql(o,w)}(await pc(s),s.asyncQueue,t,e,n)),n.promise}/**
 * @license
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function Aa(s){const t={};return s.timeoutSeconds!==void 0&&(t.timeoutSeconds=s.timeoutSeconds),t}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const mo=new Map;/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const wa="firestore.googleapis.com",go=!0;class po{constructor(t){if(t.host===void 0){if(t.ssl!==void 0)throw new k(S.INVALID_ARGUMENT,"Can't provide ssl option if host option is not set");this.host=wa,this.ssl=go}else this.host=t.host,this.ssl=t.ssl??go;if(this.isUsingEmulator=t.emulatorOptions!==void 0,this.credentials=t.credentials,this.ignoreUndefinedProperties=!!t.ignoreUndefinedProperties,this.localCache=t.localCache,t.cacheSizeBytes===void 0)this.cacheSizeBytes=oa;else{if(t.cacheSizeBytes!==-1&&t.cacheSizeBytes<rl)throw new k(S.INVALID_ARGUMENT,"cacheSizeBytes must be at least 1048576");this.cacheSizeBytes=t.cacheSizeBytes}Lu("experimentalForceLongPolling",t.experimentalForceLongPolling,"experimentalAutoDetectLongPolling",t.experimentalAutoDetectLongPolling),this.experimentalForceLongPolling=!!t.experimentalForceLongPolling,this.experimentalForceLongPolling?this.experimentalAutoDetectLongPolling=!1:t.experimentalAutoDetectLongPolling===void 0?this.experimentalAutoDetectLongPolling=!0:this.experimentalAutoDetectLongPolling=!!t.experimentalAutoDetectLongPolling,this.experimentalLongPollingOptions=Aa(t.experimentalLongPollingOptions??{}),function(n){if(n.timeoutSeconds!==void 0){if(isNaN(n.timeoutSeconds))throw new k(S.INVALID_ARGUMENT,`invalid long polling timeout: ${n.timeoutSeconds} (must not be NaN)`);if(n.timeoutSeconds<5)throw new k(S.INVALID_ARGUMENT,`invalid long polling timeout: ${n.timeoutSeconds} (minimum allowed value is 5)`);if(n.timeoutSeconds>30)throw new k(S.INVALID_ARGUMENT,`invalid long polling timeout: ${n.timeoutSeconds} (maximum allowed value is 30)`)}}(this.experimentalLongPollingOptions),this.useFetchStreams=!!t.useFetchStreams}isEqual(t){return this.host===t.host&&this.ssl===t.ssl&&this.credentials===t.credentials&&this.cacheSizeBytes===t.cacheSizeBytes&&this.experimentalForceLongPolling===t.experimentalForceLongPolling&&this.experimentalAutoDetectLongPolling===t.experimentalAutoDetectLongPolling&&function(n,i){return n.timeoutSeconds===i.timeoutSeconds}(this.experimentalLongPollingOptions,t.experimentalLongPollingOptions)&&this.ignoreUndefinedProperties===t.ignoreUndefinedProperties&&this.useFetchStreams===t.useFetchStreams}}class Ts{constructor(t,e,n,i){this._authCredentials=t,this._appCheckCredentials=e,this._databaseId=n,this._app=i,this.type="firestore-lite",this._persistenceKey="(lite)",this._settings=new po({}),this._settingsFrozen=!1,this._emulatorOptions={},this._terminateTask="notTerminated"}get app(){if(!this._app)throw new k(S.FAILED_PRECONDITION,"Firestore was not initialized using the Firebase SDK. 'app' is not available");return this._app}get _initialized(){return this._settingsFrozen}get _terminated(){return this._terminateTask!=="notTerminated"}_setSettings(t){if(this._settingsFrozen)throw new k(S.FAILED_PRECONDITION,"Firestore has already been started and its settings can no longer be changed. You can only modify settings before calling any other methods on a Firestore object.");this._settings=new po(t),this._emulatorOptions=t.emulatorOptions||{},t.credentials!==void 0&&(this._authCredentials=function(n){if(!n)return new Pu;switch(n.type){case"firstParty":return new Du(n.sessionIndex||"0",n.iamToken||null,n.authTokenFactory||null);case"provider":return n.client;default:throw new k(S.INVALID_ARGUMENT,"makeAuthCredentialsProvider failed due to invalid credential type")}}(t.credentials))}_getSettings(){return this._settings}_getEmulatorOptions(){return this._emulatorOptions}_freezeSettings(){return this._settingsFrozen=!0,this._settings}_delete(){return this._terminateTask==="notTerminated"&&(this._terminateTask=this._terminate()),this._terminateTask}async _restart(){this._terminateTask==="notTerminated"?await this._terminate():this._terminateTask="notTerminated"}toJSON(){return{app:this._app,databaseId:this._databaseId,settings:this._settings}}_terminate(){return function(e){const n=mo.get(e);n&&(D("ComponentProvider","Removing Datastore"),mo.delete(e),n.terminate())}(this),Promise.resolve()}}function yc(s,t,e,n={}){var d;s=Or(s,Ts);const i=vo(t),o=s._getSettings(),u={...o,emulatorOptions:s._getEmulatorOptions()},l=`${t}:${e}`;i&&(mu(`https://${l}`),gu("Firestore",!0)),o.host!==wa&&o.host!==l&&_e("Host has been set in both settings() and connectFirestoreEmulator(), emulator host will be used.");const f={...o,host:l,ssl:i,emulatorOptions:n};if(!pu(f,u)&&(s._setSettings(f),n.mockUserToken)){let _,w;if(typeof n.mockUserToken=="string")_=n.mockUserToken,w=gt.MOCK_USER;else{_=_u(n.mockUserToken,(d=s._app)==null?void 0:d.options.projectId);const P=n.mockUserToken.sub||n.mockUserToken.user_id;if(!P)throw new k(S.INVALID_ARGUMENT,"mockUserToken must contain 'sub' or 'user_id' field!");w=new gt(P)}s._authCredentials=new Su(new Co(_,w))}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class vs{constructor(t,e,n){this.converter=e,this._query=n,this.type="query",this.firestore=t}withConverter(t){return new vs(this.firestore,t,this._query)}}class Tt{constructor(t,e,n){this.converter=e,this._key=n,this.type="document",this.firestore=t}get _path(){return this._key.path}get id(){return this._key.path.lastSegment()}get path(){return this._key.path.canonicalString()}get parent(){return new rn(this.firestore,this.converter,this._key.path.popLast())}withConverter(t){return new Tt(this.firestore,t,this._key)}toJSON(){return{type:Tt._jsonSchemaVersion,referencePath:this._key.toString()}}static fromJSON(t,e,n){if(sn(e,Tt._jsonSchema))return new Tt(t,n||null,new x(Q.fromString(e.referencePath)))}}Tt._jsonSchemaVersion="firestore/documentReference/1.0",Tt._jsonSchema={type:tt("string",Tt._jsonSchemaVersion),referencePath:tt("string")};class rn extends vs{constructor(t,e,n){super(t,e,ss(n)),this._path=n,this.type="collection"}get id(){return this._query.path.lastSegment()}get path(){return this._query.path.canonicalString()}get parent(){const t=this._path.popLast();return t.isEmpty()?null:new Tt(this.firestore,null,new x(t))}withConverter(t){return new rn(this.firestore,t,this._path)}}function Dc(s,t,...e){if(s=du(s),arguments.length===1&&(t=Zr.newId()),Mu("doc","path",t),s instanceof Ts){const n=Q.fromString(t,...e);return Vi(n),new Tt(s,null,new x(n))}{if(!(s instanceof Tt||s instanceof rn))throw new k(S.INVALID_ARGUMENT,"Expected first argument to collection() to be a CollectionReference, a DocumentReference or FirebaseFirestore");const n=s._path.child(Q.fromString(t,...e));return Vi(n),new Tt(s.firestore,s instanceof rn?s.converter:null,new x(n))}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */const _o="AsyncQueue";class yo{constructor(t=Promise.resolve()){this.Xu=[],this.ec=!1,this.tc=[],this.nc=null,this.rc=!1,this.sc=!1,this.oc=[],this.M_=new ca(this,"async_queue_retry"),this._c=()=>{const n=Nr();n&&D(_o,"Visibility state changed to "+n.visibilityState),this.M_.w_()},this.ac=t;const e=Nr();e&&typeof e.addEventListener=="function"&&e.addEventListener("visibilitychange",this._c)}get isShuttingDown(){return this.ec}enqueueAndForget(t){this.enqueue(t)}enqueueAndForgetEvenWhileRestricted(t){this.uc(),this.cc(t)}enterRestrictedMode(t){if(!this.ec){this.ec=!0,this.sc=t||!1;const e=Nr();e&&typeof e.removeEventListener=="function"&&e.removeEventListener("visibilitychange",this._c)}}enqueue(t){if(this.uc(),this.ec)return new Promise(()=>{});const e=new ne;return this.cc(()=>this.ec&&this.sc?Promise.resolve():(t().then(e.resolve,e.reject),e.promise)).then(()=>e.promise)}enqueueRetryable(t){this.enqueueAndForget(()=>(this.Xu.push(t),this.lc()))}async lc(){if(this.Xu.length!==0){try{await this.Xu[0](),this.Xu.shift(),this.M_.reset()}catch(t){if(!Re(t))throw t;D(_o,"Operation failed with retryable error: "+t)}this.Xu.length>0&&this.M_.p_(()=>this.lc())}}cc(t){const e=this.ac.then(()=>(this.rc=!0,t().catch(n=>{throw this.nc=n,this.rc=!1,Ot("INTERNAL UNHANDLED ERROR: ",Eo(n)),n}).then(n=>(this.rc=!1,n))));return this.ac=e,e}enqueueAfterDelay(t,e,n){this.uc(),this.oc.indexOf(t)>-1&&(e=0);const i=ps.createAndSchedule(this,t,e,n,o=>this.hc(o));return this.tc.push(i),i}uc(){this.nc&&L(47125,{Pc:Eo(this.nc)})}verifyOperationInProgress(){}async Tc(){let t;do t=this.ac,await t;while(t!==this.ac)}Ic(t){for(const e of this.tc)if(e.timerId===t)return!0;return!1}Ec(t){return this.Tc().then(()=>{this.tc.sort((e,n)=>e.targetTimeMs-n.targetTimeMs);for(const e of this.tc)if(e.skipDelay(),t!=="all"&&e.timerId===t)break;return this.Tc()})}dc(t){this.oc.push(t)}hc(t){const e=this.tc.indexOf(t);this.tc.splice(e,1)}}function Eo(s){let t=s.message||"";return s.stack&&(t=s.stack.includes(s.message)?s.stack:s.message+`
`+s.stack),t}class Ra extends Ts{constructor(t,e,n,i){super(t,e,n,i),this.type="firestore",this._queue=new yo,this._persistenceKey=(i==null?void 0:i.name)||"[DEFAULT]"}async _terminate(){if(this._firestoreClient){const t=this._firestoreClient.terminate();this._queue=new yo(t),this._firestoreClient=void 0,await t}}}function Nc(s,t){const e=typeof s=="object"?s:lu(),n=typeof s=="string"?s:t||Un,i=cu(e,"firestore").getImmediate({identifier:n});if(!i._initialized){const o=fu("firestore");o&&yc(i,...o)}return i}function Ec(s){if(s._terminated)throw new k(S.FAILED_PRECONDITION,"The client has already been terminated.");return s._firestoreClient||Tc(s),s._firestoreClient}function Tc(s){var n,i,o;const t=s._freezeSettings(),e=function(l,f,d,_){return new Yu(l,f,d,_.host,_.ssl,_.experimentalForceLongPolling,_.experimentalAutoDetectLongPolling,Aa(_.experimentalLongPollingOptions),_.useFetchStreams,_.isUsingEmulator)}(s._databaseId,((n=s._app)==null?void 0:n.options.appId)||"",s._persistenceKey,t);s._componentsProvider||(i=t.localCache)!=null&&i._offlineComponentProvider&&((o=t.localCache)!=null&&o._onlineComponentProvider)&&(s._componentsProvider={_offline:t.localCache._offlineComponentProvider,_online:t.localCache._onlineComponentProvider}),s._firestoreClient=new dc(s._authCredentials,s._appCheckCredentials,s._queue,e,s._componentsProvider&&function(l){const f=l==null?void 0:l._online.build();return{_offline:l==null?void 0:l._offline.build(f),_online:f}}(s._componentsProvider))}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Pt{constructor(t){this._byteString=t}static fromBase64String(t){try{return new Pt(ht.fromBase64String(t))}catch(e){throw new k(S.INVALID_ARGUMENT,"Failed to construct data from Base64 string: "+e)}}static fromUint8Array(t){return new Pt(ht.fromUint8Array(t))}toBase64(){return this._byteString.toBase64()}toUint8Array(){return this._byteString.toUint8Array()}toString(){return"Bytes(base64: "+this.toBase64()+")"}isEqual(t){return this._byteString.isEqual(t._byteString)}toJSON(){return{type:Pt._jsonSchemaVersion,bytes:this.toBase64()}}static fromJSON(t){if(sn(t,Pt._jsonSchema))return Pt.fromBase64String(t.bytes)}}Pt._jsonSchemaVersion="firestore/bytes/1.0",Pt._jsonSchema={type:tt("string",Pt._jsonSchemaVersion),bytes:tt("string")};/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Pa{constructor(...t){for(let e=0;e<t.length;++e)if(t[e].length===0)throw new k(S.INVALID_ARGUMENT,"Invalid field name at argument $(i + 1). Field names must not be empty.");this._internalPath=new Et(t)}isEqual(t){return this._internalPath.isEqual(t._internalPath)}}/**
 * @license
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class zt{constructor(t,e){if(!isFinite(t)||t<-90||t>90)throw new k(S.INVALID_ARGUMENT,"Latitude must be a number between -90 and 90, but was: "+t);if(!isFinite(e)||e<-180||e>180)throw new k(S.INVALID_ARGUMENT,"Longitude must be a number between -180 and 180, but was: "+e);this._lat=t,this._long=e}get latitude(){return this._lat}get longitude(){return this._long}isEqual(t){return this._lat===t._lat&&this._long===t._long}_compareTo(t){return F(this._lat,t._lat)||F(this._long,t._long)}toJSON(){return{latitude:this._lat,longitude:this._long,type:zt._jsonSchemaVersion}}static fromJSON(t){if(sn(t,zt._jsonSchema))return new zt(t.latitude,t.longitude)}}zt._jsonSchemaVersion="firestore/geoPoint/1.0",zt._jsonSchema={type:tt("string",zt._jsonSchemaVersion),latitude:tt("number"),longitude:tt("number")};/**
 * @license
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Gt{constructor(t){this._values=(t||[]).map(e=>e)}toArray(){return this._values.map(t=>t)}isEqual(t){return function(n,i){if(n.length!==i.length)return!1;for(let o=0;o<n.length;++o)if(n[o]!==i[o])return!1;return!0}(this._values,t._values)}toJSON(){return{type:Gt._jsonSchemaVersion,vectorValues:this._values}}static fromJSON(t){if(sn(t,Gt._jsonSchema)){if(Array.isArray(t.vectorValues)&&t.vectorValues.every(e=>typeof e=="number"))return new Gt(t.vectorValues);throw new k(S.INVALID_ARGUMENT,"Expected 'vectorValues' field to be a number array")}}}Gt._jsonSchemaVersion="firestore/vectorValue/1.0",Gt._jsonSchema={type:tt("string",Gt._jsonSchemaVersion),vectorValues:tt("object")};const vc=new RegExp("[~\\*/\\[\\]]");function Ic(s,t,e){if(t.search(vc)>=0)throw To(`Invalid field path (${t}). Paths must not contain '~', '*', '/', '[', or ']'`,s);try{return new Pa(...t.split("."))._internalPath}catch{throw To(`Invalid field path (${t}). Paths must not be empty, begin with '.', end with '.', or contain '..'`,s)}}function To(s,t,e,n,i){let o=`Function ${t}() called with invalid data`;o+=". ";let u="";return new k(S.INVALID_ARGUMENT,o+s+u)}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */class Sa{constructor(t,e,n,i,o){this._firestore=t,this._userDataWriter=e,this._key=n,this._document=i,this._converter=o}get id(){return this._key.path.lastSegment()}get ref(){return new Tt(this._firestore,this._converter,this._key)}exists(){return this._document!==null}data(){if(this._document){if(this._converter){const t=new Ac(this._firestore,this._userDataWriter,this._key,this._document,null);return this._converter.fromFirestore(t)}return this._userDataWriter.convertValue(this._document.data.value)}}get(t){if(this._document){const e=this._document.data.field(Va("DocumentSnapshot.get",t));if(e!==null)return this._userDataWriter.convertValue(e)}}}class Ac extends Sa{data(){return super.data()}}function Va(s,t){return typeof t=="string"?Ic(s,t):t instanceof Pa?t._internalPath:t._delegate._internalPath}class wc{convertValue(t,e="none"){switch(Ht(t)){case 0:return null;case 1:return t.booleanValue;case 2:return X(t.integerValue||t.doubleValue);case 3:return this.convertTimestamp(t.timestampValue);case 4:return this.convertServerTimestamp(t,e);case 5:return t.stringValue;case 6:return this.convertBytes(Qt(t.bytesValue));case 7:return this.convertReference(t.referenceValue);case 8:return this.convertGeoPoint(t.geoPointValue);case 9:return this.convertArray(t.arrayValue,e);case 11:return this.convertObject(t.mapValue,e);case 10:return this.convertVectorValue(t.mapValue);default:throw L(62114,{value:t})}}convertObject(t,e){return this.convertObjectMap(t.fields,e)}convertObjectMap(t,e="none"){const n={};return on(t,(i,o)=>{n[i]=this.convertValue(o,e)}),n}convertVectorValue(t){var n,i,o;const e=(o=(i=(n=t.fields)==null?void 0:n[Lr].arrayValue)==null?void 0:i.values)==null?void 0:o.map(u=>X(u.doubleValue));return new Gt(e)}convertGeoPoint(t){return new zt(X(t.latitude),X(t.longitude))}convertArray(t,e){return(t.values||[]).map(n=>this.convertValue(n,e))}convertServerTimestamp(t,e){switch(e){case"previous":const n=Wn(t);return n==null?null:this.convertValue(n,e);case"estimate":return this.convertTimestamp(tn(t));default:return null}}convertTimestamp(t){const e=$t(t);return new Z(e.seconds,e.nanos)}convertDocumentKey(t,e){const n=Q.fromString(t);H(ia(n),9688,{name:t});const i=new en(n.get(1),n.get(3)),o=new x(n.popFirst(5));return i.isEqual(e)||Ot(`Document ${o} contains a document reference within a different database (${i.projectId}/${i.database}) which is not supported. It will be treated as a reference in the current database (${e.projectId}/${e.database}) instead.`),o}}class Qe{constructor(t,e){this.hasPendingWrites=t,this.fromCache=e}isEqual(t){return this.hasPendingWrites===t.hasPendingWrites&&this.fromCache===t.fromCache}}class se extends Sa{constructor(t,e,n,i,o,u){super(t,e,n,i,u),this._firestore=t,this._firestoreImpl=t,this.metadata=o}exists(){return super.exists()}data(t={}){if(this._document){if(this._converter){const e=new Fn(this._firestore,this._userDataWriter,this._key,this._document,this.metadata,null);return this._converter.fromFirestore(e,t)}return this._userDataWriter.convertValue(this._document.data.value,t.serverTimestamps)}}get(t,e={}){if(this._document){const n=this._document.data.field(Va("DocumentSnapshot.get",t));if(n!==null)return this._userDataWriter.convertValue(n,e.serverTimestamps)}}toJSON(){if(this.metadata.hasPendingWrites)throw new k(S.FAILED_PRECONDITION,"DocumentSnapshot.toJSON() attempted to serialize a document with pending writes. Await waitForPendingWrites() before invoking toJSON().");const t=this._document,e={};return e.type=se._jsonSchemaVersion,e.bundle="",e.bundleSource="DocumentSnapshot",e.bundleName=this._key.toString(),!t||!t.isValidDocument()||!t.isFoundDocument()?e:(this._userDataWriter.convertObjectMap(t.data.value.mapValue.fields,"previous"),e.bundle=(this._firestore,this.ref.path,"NOT SUPPORTED"),e)}}se._jsonSchemaVersion="firestore/documentSnapshot/1.0",se._jsonSchema={type:tt("string",se._jsonSchemaVersion),bundleSource:tt("string","DocumentSnapshot"),bundleName:tt("string"),bundle:tt("string")};class Fn extends se{data(t={}){return super.data(t)}}class Je{constructor(t,e,n,i){this._firestore=t,this._userDataWriter=e,this._snapshot=i,this.metadata=new Qe(i.hasPendingWrites,i.fromCache),this.query=n}get docs(){const t=[];return this.forEach(e=>t.push(e)),t}get size(){return this._snapshot.docs.size}get empty(){return this.size===0}forEach(t,e){this._snapshot.docs.forEach(n=>{t.call(e,new Fn(this._firestore,this._userDataWriter,n.key,n,new Qe(this._snapshot.mutatedKeys.has(n.key),this._snapshot.fromCache),this.query.converter))})}docChanges(t={}){const e=!!t.includeMetadataChanges;if(e&&this._snapshot.excludesMetadataChanges)throw new k(S.INVALID_ARGUMENT,"To include metadata changes with your document changes, you must also pass { includeMetadataChanges:true } to onSnapshot().");return this._cachedChanges&&this._cachedChangesIncludeMetadataChanges===e||(this._cachedChanges=function(i,o){if(i._snapshot.oldDocs.isEmpty()){let u=0;return i._snapshot.docChanges.map(l=>{const f=new Fn(i._firestore,i._userDataWriter,l.doc.key,l.doc,new Qe(i._snapshot.mutatedKeys.has(l.doc.key),i._snapshot.fromCache),i.query.converter);return l.doc,{type:"added",doc:f,oldIndex:-1,newIndex:u++}})}{let u=i._snapshot.oldDocs;return i._snapshot.docChanges.filter(l=>o||l.type!==3).map(l=>{const f=new Fn(i._firestore,i._userDataWriter,l.doc.key,l.doc,new Qe(i._snapshot.mutatedKeys.has(l.doc.key),i._snapshot.fromCache),i.query.converter);let d=-1,_=-1;return l.type!==0&&(d=u.indexOf(l.doc.key),u=u.delete(l.doc.key)),l.type!==1&&(u=u.add(l.doc),_=u.indexOf(l.doc.key)),{type:Rc(l.type),doc:f,oldIndex:d,newIndex:_}})}}(this,e),this._cachedChangesIncludeMetadataChanges=e),this._cachedChanges}toJSON(){if(this.metadata.hasPendingWrites)throw new k(S.FAILED_PRECONDITION,"QuerySnapshot.toJSON() attempted to serialize a document with pending writes. Await waitForPendingWrites() before invoking toJSON().");const t={};t.type=Je._jsonSchemaVersion,t.bundleSource="QuerySnapshot",t.bundleName=Zr.newId(),this._firestore._databaseId.database,this._firestore._databaseId.projectId;const e=[],n=[],i=[];return this.docs.forEach(o=>{o._document!==null&&(e.push(o._document),n.push(this._userDataWriter.convertObjectMap(o._document.data.value.mapValue.fields,"previous")),i.push(o.ref.path))}),t.bundle=(this._firestore,this.query._query,t.bundleName,"NOT SUPPORTED"),t}}function Rc(s){switch(s){case 0:return"added";case 2:case 3:return"modified";case 1:return"removed";default:return L(61501,{type:s})}}/**
 * @license
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */function kc(s){s=Or(s,Tt);const t=Or(s.firestore,Ra);return _c(Ec(t),s._key).then(e=>Sc(t,s,e))}Je._jsonSchemaVersion="firestore/querySnapshot/1.0",Je._jsonSchema={type:tt("string",Je._jsonSchemaVersion),bundleSource:tt("string","QuerySnapshot"),bundleName:tt("string"),bundle:tt("string")};class Pc extends wc{constructor(t){super(),this.firestore=t}convertBytes(t){return new Pt(t)}convertReference(t){const e=this.convertDocumentKey(t,this.firestore._databaseId);return new Tt(this.firestore,null,e)}}function Sc(s,t,e){const n=e.docs.get(t._key),i=new Pc(s);return new se(s,i,t._key,n,new Qe(e.hasPendingWrites,e.fromCache),t.converter)}(function(t,e=!0){(function(i){we=i})(Iu),Au(new wu("firestore",(n,{instanceIdentifier:i,options:o})=>{const u=n.getProvider("app").getImmediate(),l=new Ra(new Vu(n.getProvider("auth-internal")),new Nu(u,n.getProvider("app-check-internal")),function(d,_){if(!Object.prototype.hasOwnProperty.apply(d.options,["projectId"]))throw new k(S.INVALID_ARGUMENT,'"projectId" not provided in firebase.initializeApp.');return new en(d.options.projectId,_)}(u,i),u);return o={useFetchStreams:e,...o},l._setSettings(o),l},"PUBLIC").setMultipleInstances(!0)),Ii(wi,Ri,t),Ii(wi,Ri,"esm2020")})();export{wc as AbstractUserDataWriter,Pt as Bytes,rn as CollectionReference,Tt as DocumentReference,se as DocumentSnapshot,Pa as FieldPath,Ra as Firestore,k as FirestoreError,zt as GeoPoint,vs as Query,Fn as QueryDocumentSnapshot,Je as QuerySnapshot,Qe as SnapshotMetadata,Z as Timestamp,Gt as VectorValue,Zr as _AutoId,ht as _ByteString,en as _DatabaseId,x as _DocumentKey,Pu as _EmptyAuthCredentialsProvider,Et as _FieldPath,Or as _cast,_e as _logWarn,Lu as _validateIsNotUsedTogether,yc as connectFirestoreEmulator,Dc as doc,Ec as ensureFirestoreConfigured,kc as getDoc,Nc as getFirestore};
