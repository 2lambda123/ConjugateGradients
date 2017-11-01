"""Test matrices"""
import random

from numpy.ma import ceil, sqrt
from numpy.ma import floor

import numpy as np
from scipy.sparse.csr import csr_matrix


class TestMatrices:
    """Test matrices generating methods."""

    @classmethod
    def get_diagonal_matrix(cls, size: int = 50) -> np.matrix:
        """Return size by size test diagonal matrix."""
        diagonal = np.diagflat([1] * size)
        return np.matrix(diagonal)

    @classmethod
    def get_diagonal_matrix_csr(cls, size: int = 50) -> np.matrix:
        """Return diagonal matrix in CSR format."""
        return csr_matrix(cls.get_diagonal_matrix(size=size))

    @classmethod
    def get_matrix_three_diagonal(cls, size: int = 50) -> np.matrix:
        """Return size by size test 3 diagonal matrix."""
        upper_diagonal = np.diagflat([1] * (size - 1), 1)
        lower_diagonal = np.diagflat([1] * (size - 1), -1)
        diagonal = np.diagflat([10] * size)
        return np.matrix(lower_diagonal + diagonal + upper_diagonal)

    @classmethod
    def get_matrix_three_diagonal_csr(cls, size: int = 50) -> np.matrix:
        """Return three diagonal test matrix in csr format."""
        return csr_matrix(cls.get_matrix_three_diagonal(size=size))

    @staticmethod
    def _brachistochrone_mask(size: int):
        """TBI"""
        mask = np.zeros((size, size))
        return mask

    @staticmethod
    def _get_arrow_mask(size: int, density: float = 0.2):
        """Return arrow-like mask for random matrix"""
        mask = np.zeros((size, size))
        for ind in range(size):
            mask[ind, ind] = 1
        for ind in np.random.choice(size-1, int(floor(size * density))):        # pylint: disable=no-member
            length = random.randint(1, int(sqrt(ind)) + 1)
            mask[ind-length:ind, ind] = 1
            mask[ind, ind-length:ind] = 1
            how_many_elmns = random.randint(1, int(sqrt(ind)) + 1)
            for var in range(1, how_many_elmns):                                # pylint: disable=unused-variable
                length = random.randint(1, int(sqrt(size * density)))
                rnd_from = random.randint(1, ind) - length
                rnd_to = rnd_from + length
                mask[rnd_from:rnd_to, ind] = 1
                mask[ind, rnd_from:rnd_to] = 1
        return mask

    @staticmethod
    def _get_quadratic_mask(size: int):
        """Return mask for quadratic test matrix."""
        mask = np.zeros((size, size))
        offset = int(floor(size/100))   # add extra diagonal for each 100elements grown size
        for ind in range(size):
            mask[ind, ind] = 1
            mask[ind, int(ceil(ind/2))] = 1
            mask[int(ceil(ind/2)), ind] = 1
            if ind < int(size/2):
                mask[int(size/2) + ind, ind] = 1
                mask[ind, int(size/2) + ind] = 1
            for add in range(offset):
                # will add extra diagonals
                add += 1
                if ind < size - add:
                    mask[ind, ind + add] = 1
                if ind >= add:
                    mask[ind, ind - add] = 1
        for splitter in range(int(np.sqrt(size))):
            matrix_splitter = ceil((pow(2, splitter + 1)))
            split_value = size - int(size/matrix_splitter)
            for ind in range(split_value, size):
                mask[ind, split_value] = 1
                mask[split_value, ind] = 1
        return mask

    @classmethod
    def get_random_test_matrix(cls, size: int = 50, distribution: str = 'quadratic') -> np.matrix:
        """Return positively defined matrix used for testing purposes.

        Matrix will be positively define if its eigenvalues are positive, to achieve this it can be stated that:
        A = Q'DQ, where Q is random matrix, D diagonal matrix with positive elements on its diagonal.
        """
        rand_matrix = np.matrix(np.random.rand(size, size))    # pylint: disable=no-member
        # lets make it diagonally dominant:
        d_matrix = np.diagflat([1] * size)
        q_matrix = rand_matrix.T * d_matrix * rand_matrix
        # log used to reduce growth of values when size gets greater
        q_matrix = q_matrix / np.log(q_matrix.size)     # pylint: disable=no-member
        if distribution == 'quadratic':
            return np.multiply(q_matrix, cls._get_quadratic_mask(size))
        elif distribution == 'arrow':
            return np.multiply(q_matrix, cls._get_arrow_mask(size))
        else:
            raise NotImplementedError

    @classmethod
    def get_random_test_matrix_csr(cls, size: int = 50, distribution: str = 'quadratic') -> np.matrix:
        """Return random test matrix in csr format."""
        return csr_matrix(cls.get_random_test_matrix(size=size, distribution=distribution))
