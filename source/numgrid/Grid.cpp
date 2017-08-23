/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "numgrid.h"
#include "Grid.h"

#include <algorithm>
#include <cmath>

#include "error_handling.h"
#include "becke_partitioning.h"
#include "grid_radial.h"
#include "parameters.h"
#include "sphere_lebedev_rule.h"

#define AS_TYPE(Type, Obj) reinterpret_cast<Type *>(Obj)
#define AS_CTYPE(Type, Obj) reinterpret_cast<const Type *>(Obj)

context_t *numgrid_new_context() { return AS_TYPE(context_t, new Grid()); }
Grid::Grid() { nullify(); }

void numgrid_free_context(context_t *context)
{
    if (!context)
        return;
    delete AS_TYPE(Grid, context);
}
Grid::~Grid()
{
    delete[] xyzw;
    nullify();
}

int numgrid_get_num_points(const context_t *context)
{
    return AS_CTYPE(Grid, context)->numgrid_get_num_points();
}
int Grid::numgrid_get_num_points() const { return num_points; }

const double * const numgrid_get_grid(const context_t *context)
{
    return AS_CTYPE(Grid, context)->numgrid_get_grid();
}
const double * const Grid::numgrid_get_grid() const { return xyzw; }

void Grid::nullify()
{
    xyzw = NULL;
    num_points = -1;
}

int lebedev_table[33] = {6,    14,   26,   38,   50,   74,   86,   110,  146,
                         170,  194,  230,  266,  302,  350,  434,  590,  770,
                         974,  1202, 1454, 1730, 2030, 2354, 2702, 3074, 3470,
                         3890, 4334, 4802, 4934, 5294, 5810};

int Grid::get_closest_num_angular(int n) const
{
    int m;

    for (int i = 0; i < MAX_ANGULAR_ORDER; i++)
    {
        m = lebedev_table[i];
        if (m >= n)
            return m;
    }

    NUMGRID_ERROR("Input n too high in get_closest_num_angular");
}

int Grid::get_angular_order(int n) const
{
    for (int i = 0; i < MAX_ANGULAR_ORDER; i++)
    {
        if (lebedev_table[i] == n)
            return i;
    }

    NUMGRID_ERROR("No match found in get_angular_offset");
}

int numgrid_generate_grid(context_t *context,
                          const double radial_precision,
                          const int min_num_angular_points,
                          const int max_num_angular_points,
                          const int num_centers,
                          const double center_coordinates[],
                          const int center_elements[],
                          const int num_outer_centers,
                          const double outer_center_coordinates[],
                          const int outer_center_elements[],
                          const int num_shells,
                          const int shell_centers[],
                          const int shell_l_quantum_numbers[],
                          const int shell_num_primitives[],
                          const double primitive_exponents[])
{
    return AS_TYPE(Grid, context)
        ->generate(radial_precision,
                   min_num_angular_points,
                   max_num_angular_points,
                   num_centers,
                   center_coordinates,
                   center_elements,
                   num_outer_centers,
                   outer_center_coordinates,
                   outer_center_elements,
                   num_shells,
                   shell_centers,
                   shell_l_quantum_numbers,
                   shell_num_primitives,
                   primitive_exponents);
}
int Grid::generate(const double radial_precision,
                   const int min_num_angular_points,
                   const int max_num_angular_points,
                   const int num_centers,
                   const double center_coordinates[],
                   const int center_elements[],
                   const int num_outer_centers,
                   const double outer_center_coordinates[],
                   const int outer_center_elements[],
                   const int num_shells,
                   const int shell_centers[],
                   const int shell_l_quantum_numbers[],
                   const int shell_num_primitives[],
                   const double primitive_exponents[])
{
    int num_min_num_angular_points =
        get_closest_num_angular(min_num_angular_points);
    int num_max_num_angular_points =
        get_closest_num_angular(max_num_angular_points);

    double *angular_x = new double[MAX_ANGULAR_ORDER * MAX_ANGULAR_GRID];
    double *angular_y = new double[MAX_ANGULAR_ORDER * MAX_ANGULAR_GRID];
    double *angular_z = new double[MAX_ANGULAR_ORDER * MAX_ANGULAR_GRID];
    double *angular_w = new double[MAX_ANGULAR_ORDER * MAX_ANGULAR_GRID];

    int num_centers_total = num_centers + num_outer_centers;
    double *center_coordinates_total = new double[3 * num_centers_total];

    int *center_elements_total = new int[num_centers_total];

    int i = 0;
    for (int icent = 0; icent < num_centers; icent++)
    {
        center_coordinates_total[i * 3 + 0] = center_coordinates[icent * 3 + 0];
        center_coordinates_total[i * 3 + 1] = center_coordinates[icent * 3 + 1];
        center_coordinates_total[i * 3 + 2] = center_coordinates[icent * 3 + 2];
        center_elements_total[i] = center_elements[icent];
        i++;
    }
    for (int icent = 0; icent < num_outer_centers; icent++)
    {
        center_coordinates_total[i * 3 + 0] =
            outer_center_coordinates[icent * 3 + 0];
        center_coordinates_total[i * 3 + 1] =
            outer_center_coordinates[icent * 3 + 1];
        center_coordinates_total[i * 3 + 2] =
            outer_center_coordinates[icent * 3 + 2];
        center_elements_total[i] = outer_center_elements[icent];
        i++;
    }

    for (int i = get_angular_order(num_min_num_angular_points);
         i <= get_angular_order(num_max_num_angular_points);
         i++)
    {
        int angular_off = i * MAX_ANGULAR_GRID;
        ld_by_order(lebedev_table[i],
                    &angular_x[angular_off],
                    &angular_y[angular_off],
                    &angular_z[angular_off],
                    &angular_w[angular_off]);
    }

    int *num_points_on_atom = new int[num_centers];

    // first round figures out dimensions
    // second round allocates and does the real work
    for (int iround = 0; iround < 2; iround++)
    {
        double *pa_buffer = new double[num_centers_total];

        for (int icent = 0; icent < num_centers; icent++)
        {
            int num_shells_on_this_center = 0;
            int l_max = 0;
            for (int ishell = 0; ishell < num_shells; ishell++)
            {
                if ((shell_centers[ishell] - 1) == icent)
                {
                    l_max = std::max(l_max, shell_l_quantum_numbers[ishell]);
                    num_shells_on_this_center++;
                }
            }

            // skip this center if there are no shells
            if (num_shells_on_this_center == 0)
            {
                num_points_on_atom[icent] = 0;
                continue;
            }

            // get extreme alpha values
            double alpha_max = 0.0;
            double *alpha_min = new double[l_max + 1];
            bool *alpha_min_set = new bool[l_max + 1];
            std::fill(&alpha_min[0], &alpha_min[l_max + 1], 0.0);
            std::fill(&alpha_min_set[0], &alpha_min_set[l_max + 1], false);

            int n = 0;
            for (int ishell = 0; ishell < num_shells; ishell++)
            {
                if ((shell_centers[ishell] - 1) == icent)
                {
                    int l = shell_l_quantum_numbers[ishell];

                    if (!alpha_min_set[l])
                    {
                        alpha_min[l] = 1.0e50;
                        alpha_min_set[l] = true;
                    }

                    for (int p = 0; p < shell_num_primitives[ishell]; p++)
                    {
                        double e = primitive_exponents[n];
                        alpha_max = std::max(
                            alpha_max, 2.0 * e); // factor 2.0 to match DIRAC
                        alpha_min[l] = std::min(alpha_min[l], e);
                    }
                }
                n += shell_num_primitives[ishell];
            }

            // obtain radial parameters
            double r_inner = get_r_inner(radial_precision, alpha_max);
            double h = 1.0e50;
            double r_outer = 0.0;
            for (int l = 0; l <= l_max; l++)
            {
                if (alpha_min[l] > 0.0)
                {
                    r_outer = std::max(
                        r_outer,
                        get_r_outer(
                            radial_precision,
                            alpha_min[l],
                            l,
                            4.0 * get_bragg_angstrom(center_elements[icent])));
                    NUMGRID_ASSERT(r_outer > r_inner);
                    h = std::min(
                        h,
                        get_h(radial_precision, l, 0.1 * (r_outer - r_inner)));
                }
            }
            NUMGRID_ASSERT(r_outer > h);

            delete[] alpha_min;
            delete[] alpha_min_set;

            int ioff = 0;

            if (iround == 0)
            {
                num_points_on_atom[icent] = 0;
            }
            else
            {
                for (int jcent = 0; jcent < icent; jcent++)
                {
                    ioff += num_points_on_atom[jcent];
                }
            }

            double rb = get_bragg_angstrom(center_elements[icent]) /
                        (5.0 * 0.529177249); // factors match DIRAC code
            double c = r_inner / (exp(h) - 1.0);
            int num_radial = int(log(1.0 + (r_outer / c)) / h);
            for (int irad = 0; irad < num_radial; irad++)
            {
                double radial_r = c * (exp((irad + 1) * h) - 1.0);
                double radial_w = (radial_r + c) * radial_r * radial_r * h;

                int num_angular = num_max_num_angular_points;
                if (radial_r < rb)
                {
                    num_angular = static_cast<int>(num_max_num_angular_points *
                                                   (radial_r / rb));
                    num_angular = get_closest_num_angular(num_angular);
                    if (num_angular < num_min_num_angular_points)
                        num_angular = num_min_num_angular_points;
                }

                if (iround == 0)
                {
                    num_points_on_atom[icent] += num_angular;
                }
                else
                {
                    int angular_off =
                        get_angular_order(num_angular) * MAX_ANGULAR_GRID;

                    for (int iang = 0; iang < num_angular; iang++)
                    {
                        xyzw[4 * (ioff + iang)] =
                            center_coordinates[icent * 3] +
                            angular_x[angular_off + iang] * radial_r;
                        xyzw[4 * (ioff + iang) + 1] =
                            center_coordinates[icent * 3 + 1] +
                            angular_y[angular_off + iang] * radial_r;
                        xyzw[4 * (ioff + iang) + 2] =
                            center_coordinates[icent * 3 + 2] +
                            angular_z[angular_off + iang] * radial_r;

                        double becke_w = 1.0;
                        if (num_centers_total > 1)
                        {
                            becke_w = get_becke_w(center_coordinates_total,
                                                  center_elements_total,
                                                  pa_buffer,
                                                  icent,
                                                  num_centers_total,
                                                  xyzw[4 * (ioff + iang)],
                                                  xyzw[4 * (ioff + iang) + 1],
                                                  xyzw[4 * (ioff + iang) + 2]);
                        }
                        xyzw[4 * (ioff + iang) + 3] =
                            4.0 * M_PI * angular_w[angular_off + iang] *
                            radial_w * becke_w;
                    }
                }

                ioff += num_angular;
            }
        }

        delete[] pa_buffer;

        if (iround == 0)
        {
            num_points = 0;
            for (int icent = 0; icent < num_centers; icent++)
            {
                num_points += num_points_on_atom[icent];
            }

            xyzw = new double[4 * num_points];
        }
    }

    delete[] num_points_on_atom;

    delete[] angular_x;
    delete[] angular_y;
    delete[] angular_z;
    delete[] angular_w;

    delete[] center_coordinates_total;
    delete[] center_elements_total;

    return 0;
}
