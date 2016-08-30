#include <Rcpp.h>
using namespace Rcpp;

#include <cmath>
#include <algorithm>


// generic function for kl_divergence
template <typename InputIterator1, typename InputIterator2>
inline double cosin(InputIterator1 begin1, InputIterator1 end1, InputIterator2 begin2, InputIterator2 end2) {
  
   // value to return
   double rval = 0;
   double x1Square = 0;
   double x2Square = 0;

   // set iterators to beginning of ranges
   InputIterator1 it1 = begin1;
   InputIterator2 it2 = begin2;
   
   while (it1 != end1) {
      
      // take the value and increment the iterator
      double d1 = *it1++;
      double d2 = *it2++;
      
      x1Square += d1*d1;
      x2Square += d2*d2;
   }

   InputIterator1 it3 = begin1;
   InputIterator2 it4 = begin2;
   // for each input item
   while (it3 != end1) {
      
      // take the value and increment the iterator
      double d1 = *it3++;
      double d2 = *it4++;
      
      rval += (d1 / std::sqrt(x1Square)) * (d2 / std::sqrt(x2Square));
      // rval += d1*d2;
   }
   return rval;  
}


// [[Rcpp::export]]
NumericMatrix rcpp_distance(NumericMatrix mat) {
  
   // allocate the matrix we will return
   NumericMatrix rmat(mat.nrow(), mat.nrow());
   
   for (int i = 0; i < rmat.nrow(); i++) {
      for (int j = 0; j < i; j++) {
      
         // rows we will operate on
         NumericMatrix::Row row1 = mat.row(i);
         NumericMatrix::Row row2 = mat.row(j);
         
         double dist = cosin(row1.begin(), row1.end(), row2.begin(), row2.end());        
         // write to output matrix
         rmat(i,j) = dist;
      }
   }
   
   return rmat;
}