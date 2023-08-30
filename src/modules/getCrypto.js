export const getCrypto = async () => {
  try {
    const response = await fetch(
      'https://min-api.cryptocompare.com/data/exchanges/general?api_key=28fe1a0d73822d8751192af963f356d4351d9e412b2de9f8fd2b0573d4c4c258'
    );

    const data = await response.json();
    console.log(data);
    return Object.values(data.Data);
  } catch (error) {
    console.error('Error fetching cryptocurrency data:', error);
    return [];
  }
};
