"""
Contains implementation of Conjugate Gradient Method solver.
For more information search:
https://www.cs.cmu.edu/~quake-papers/painless-conjugate-gradient.pdf
"""

import copy
from typing import Tuple
from Solvers.mixins import Convergence
from Solvers.solver import IterativeSolver

import numpy as np


class ConjugateGradientSolver(IterativeSolver, Convergence):
    """Implements Conjugate Gradient method to solve system of linear equations."""

    def solve(self) -> Tuple[np.matrix, int]:
        """Solve system of linear equations."""
        i = 0
        x_vec = copy.deepcopy(self.x_vec)
        residual = self.b_vec - self.a_matrix * x_vec
        div = residual
        delta_new = residual.T * residual

        while i < self.max_iter and np.linalg.norm(residual) > self.tolerance:
            q_vec = self.a_matrix * div
            alpha = float(delta_new/(div.T*q_vec))
            # numpy has some problems with casting when using += notation...
            x_vec = x_vec + alpha*div
            residual = residual - alpha*q_vec
            delta_old = delta_new
            delta_new = residual.T*residual
            beta = delta_new/delta_old
            div = residual + float(beta)*div
            i += 1
        return x_vec, i
