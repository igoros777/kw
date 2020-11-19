var webPage = require('webpage');
var page = webPage.create();
var fs = require('fs');
var CookieJar = "cookiejar.json";
var pageResponses = {};

page.settings.userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.98 Safari/537.36';
page.settings.javascriptEnabled = true;
page.settings.loadImages = false;
phantom.cookiesEnabled = true;
phantom.javascriptEnabled = true;


page.onResourceReceived = function(response) {
    pageResponses[response.url] = response.status;
    fs.write(CookieJar, JSON.stringify(phantom.cookies), "w");
};
if(fs.isFile(CookieJar))
    Array.prototype.forEach.call(JSON.parse(fs.read(CookieJar)), function(x){
        phantom.addCookie(x);
    });

page.open("http://facebook.com", function(status) {
  
    if ( status === "success" ) {
        page.evaluate(function() {
              document.querySelector("input[name='email']").value = "your_facebook_email";
              document.querySelector("input[name='pass']").value = "your_facebook_password";
              document.querySelector("#login_form").submit();

              console.log("Login submitted!");
        });
        window.setTimeout(function () {
          page.render('facebook_page.png');
          phantom.exit();
        }, 5000);
   }
});
