'use strict';

const attributionManagement = () => {
  const attribution = document.querySelector('.attribution-information');
  const btnAttribution = document.querySelector('.attribution-btn');

  btnAttribution.addEventListener('click', () => {
    attribution.classList.toggle('show');
  });
};

const init = () => {
  attributionManagement();
};

init();