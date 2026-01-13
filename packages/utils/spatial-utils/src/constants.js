export const DTYPE_VALUES = {
  Uint8: {
    max: 2 ** 8 - 1,
  },
  Uint16: {
    max: 2 ** 16 - 1,
  },
  Uint32: {
    max: 2 ** 32 - 1,
  },
  Float32: {
    max: 3.4 * 10 ** 38,
  },
  Int8: {
    max: 2 ** (8 - 1) - 1,
  },
  Int16: {
    max: 2 ** (16 - 1) - 1,
  },
  Int32: {
    max: 2 ** (32 - 1) - 1,
  },
  // Cast Float64 as 32 bit float point so it can be rendered.
  Float64: {
    max: 3.4 * 10 ** 38,
  }
};

function getDomains() {
  const domains = {};
  const needMin = ['Int8', 'Int16', 'Int32'];
  Object.keys(DTYPE_VALUES).forEach((dtype) => {
    const { max } = DTYPE_VALUES[dtype];
    const min = needMin.includes(dtype) ? -(max + 1) : 0;
    domains[dtype] = [min, max];
  });
  return domains;
}

export const DOMAINS = getDomains();
