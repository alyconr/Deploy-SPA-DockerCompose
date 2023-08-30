import { getCrypto } from './getCrypto.js';
import { cryptoCards } from './templates.js';

export const renderCryptos = async (filterkey) => {
  try {
    const mainContent = document.getElementById('shows');
    const container = document.getElementById('shows-character');
    container.innerHTML = '';

    const dataObject = await getCrypto();

    const cryptos = Object.values(dataObject);

    let filterCryptos = dataObject;

    if(filterkey === 'maxvolume'){
     filterCryptos = cryptos.filter((cryptoData) =>  cryptoData.TOTALVOLUME24H.BTC > 1000
      );
      filterCryptos.sort((a, b) =>  b.TOTALVOLUME24H.BTC - a.TOTALVOLUME24H.BTC
      );
    } else if(filterkey === 'lowvolume'){
      filterCryptos = cryptos.filter((cryptoData) => 
      cryptoData.TOTALVOLUME24H.BTC < 1000
      );
      filterCryptos.sort((a, b) => 
         a.TOTALVOLUME24H.BTC - b.TOTALVOLUME24H.BTC
      );

    }
    

    filterCryptos.forEach((cryptoData) => {
      const card = document.createElement('div');
      card.classList.add(
        'col',
        'foo',
        'col-sm-6',
        'col-md-4',
        'col-lg-3',
        'py-3'
      );
      card.innerHTML = cryptoCards(cryptoData);
      container.appendChild(card);
    });
    mainContent.appendChild(container);
  } catch (error) {
    console.error('Error fetching cryptocurrency data:', error);
  }
};
