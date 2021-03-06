#' Graph Diffusion Distance
#'
#' Graph Diffusion Distance (\code{nd.gdd}) quantifies the difference between two weighted graphs of same size. It takes
#' an idea from heat diffusion process on graphs via graph Laplacian exponential kernel matrices. For a given
#' adjacency matrix \eqn{A}, the graph Laplacian is defined as
#' \deqn{L := D-A}
#' where \eqn{D_{ii}=\sum_j A_{ij}}. For two adjacency matrices \eqn{A_1} and \eqn{A_2},
#' GDD is defined as
#' \deqn{d_{gdd}(A_1,A_2) = max_t \sqrt{\| \exp(-tL_1) -\exp(-tL_2)   \|_F^2}}
#' where \eqn{\exp(\cdot)} is matrix exponential, \eqn{\|\cdot\|_F} a Frobenius norm, and \eqn{L_1} and \eqn{L_2}
#' Laplacian matrices corresponding to \eqn{A_1} and \eqn{A_2}, respectively.
#'
#' @param A a list of length \eqn{N} containing adjacency matrices.
#' @param out.dist a logical; \code{TRUE} for computed distance matrix as a \code{dist} object.
#' @param vect a vector of parameters \eqn{t} whose values will be used.
#'
#' @return a named list containing \describe{
#' \item{D}{an \eqn{(N\times N)} matrix or \code{dist} object containing pairwise distance measures.}
#' \item{maxt}{an \eqn{(N\times N)} matrix whose entries are maximizer of the cost function.}
#' }
#'
#' @examples
#' ## load data and extract a subset
#' data(graph20)
#' gr.small = graph20[c(1:5,11:15)]
#'
#' ## Compute Distance Matrix and Visualize
#' output = nd.gdd(gr.small, out.dist=FALSE)
#' opar   = par(pty="s")
#' image(output$D[,10:1], main="two group case", col=gray((0:32)/32), axes=FALSE)
#' par(opar)
#'
#' @references
#' \insertRef{hammond_graph_2013}{NetworkDistance}
#'
#' @rdname nd_gdd
#' @export
nd.gdd <- function(A, out.dist=TRUE, vect=seq(from=0.1,to=1,length.out=10)){
  #-------------------------------------------------------
  ## PREPROCESSING
  # 1. list of length larger than 1
  if ((!is.list(A))||(length(A)<=1)){
    stop("* nd.gdd : input 'A' should be a list of length larger than 1.")
  }
  # 2. transform the data while checking
  listA = list_transform(A, NIflag="not")
  # 3. vect
  if ((!is.vector(vect))||(any(vect<0))||(any(is.na(vect)))||(any(is.infinite(vect)))){
    stop("* nd.gdd : input 'vect' should be a vector of nonnegative real numbers.")
  }
  vect = sort(vect)

  #-------------------------------------------------------
  ## MAIN COMPUTATION
  # N = length(listA)
  # mat_dist = array(0,c(N,N))
  # mat_maxt = array(0,c(N,N))
  #
  # for (i in 1:(N-1)){
  #   L1 = gdd_laplacian(listA[[i]])
  #   for (j in (i+1):N){
  #     L2    = gdd_laplacian(listA[[j]])
  #     gdd12 = gdd_computedist(L1,L2,vect)
  #
  #     mat_dist[i,j] = gdd12$dist
  #     mat_dist[j,i] = gdd12$dist
  #     mat_maxt[i,j] = gdd12$maxt
  #     mat_maxt[j,i] = gdd12$maxt
  #   }
  # }

  Lprocess = list_Adj2LapEigs(listA)
  Lvecs    = Lprocess$vectors
  Lvals    = Lprocess$values

  cpprun   = cpp_gdd(Lvecs, Lvals, vect)
  mat_dist = cpprun$distmat
  mat_maxt = cpprun$timemat
  #-------------------------------------------------------
  ## RETURN RESULTS
  if (out.dist){
    mat_dist = as.dist(mat_dist)
  }

  result = list()
  result$D= mat_dist
  result$maxt= mat_maxt
  return(result)
}



#' @keywords internal
#' @noRd
gdd_laplacian <- function(tgt){
  diag(tgt) = 0
  L = diag(rowSums(tgt))-tgt
  return(L)
}

#' @keywords internal
#' @noRd
gdd_computedist <- function(L1, L2, vect){
  # 1. parallelism setting
  nCore = max(ceiling(detectCores()/2),1)
  if (nCore==1){
    cl = makeCluster(1)
    registerDoParallel(cl)
  } else {
    cl = makeCluster(nCore)
    registerDoParallel(cl)
  }
  # 2. run parallel computation
  nvect     = length(vect)
  itforeach = NULL
  Rs = foreach (itforeach=1:nvect, .combine=cbind) %dopar% {
    Matrix::norm(Matrix::expm(-vect[itforeach]*L1)-Matrix::expm(-vect[itforeach]*L2),"f")
  }
  stopCluster(cl)
  # 3. find the argmax t parameter
  idxmaxt = which(Rs==max(Rs))
  if (length(idxmaxt)>1){
    idxmaxt = idxmaxt[1]
  }
  maxt = vect[idxmaxt]
  # 4. compute the distance
  output = (Matrix::norm(Matrix::expm(-maxt*L1)-Matrix::expm(-maxt*L2),"f"))

  # 5. return both distance value and corresponding t value
  result = list()
  result$dist = output
  result$maxt = maxt
  return(result)
}








