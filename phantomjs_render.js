var page = require('webpage').create(),
system = require('system'),
address, output, size;
page.settings.resourceTimeout = 10000;
var userAgent = system.args[1];
var fs = require('fs');
page.settings.userAgent = userAgent;
if (system.args.length < 3 || system.args.length > 5) {
console.log('Usage: rasterize.js URL filename [paperwidth*paperheight|paperformat] [zoom]');
console.log('  paper (pdf output) examples: "5in*7.5in", "10cm*20cm", "A4", "Letter"');
phantom.exit(1);
} else {
address = system.args[2];
output = system.args[3];
page.viewportSize = {
width: 1440,
height: 1280
};
if (system.args.length > 3 && system.args[3].substr(-4) === ".pdf") {
size = system.args[4].split('*');
page.paperSize = size.length === 2 ? {
width: size[0],
height: size[1],
margin: '0px'
} :
{
format: system.args[4],
orientation: 'portrait',
margin: '1cm'
};
}
if (system.args.length > 4) {
page.zoomFactor = system.args[5];
}
page.open(address, function(status) {
if (status !== 'success') {
console.log('Unable to load the address!');
phantom.exit();
} else {
page.evaluate(function() {
//$("#overlay, #modal").remove();
var current = 0,
delta = 1280,
total = document.height - delta;
var style = document.createElement('style'),
text = document.createTextNode('body { background-color: #ffffff; }');
style.setAttribute('type', 'text/css');
style.appendChild(text);
document.head.insertBefore(style, document.head.firstChild);
window.scrollTo(0, current);
function fakeScroll() {
if (current < total) {
current = current + delta;
window.scrollTo(0, current);
window.setTimeout(fakeScroll, 200);
} else {
window.scrollTo(0, 0);
}
}
fakeScroll()
});
window.setTimeout(function() {
page.render(output);
fs.write('./tmp/temp.html', page.content, 'w');
phantom.exit();
}, 10000);
}
});
}
