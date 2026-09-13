document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector(".nav-toggle");
  const mobile = document.querySelector("#mobile-nav");
  if (toggle && mobile) {
    toggle.addEventListener("click", () => {
      mobile.classList.toggle("open");
    });
  }
});
