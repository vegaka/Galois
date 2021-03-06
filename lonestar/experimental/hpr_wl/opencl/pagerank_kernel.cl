/*
 * pagerank_kernel.cl
 * OpenCL kernels for PageRank on heterogeneous Galois.
 *
 *  Created on: Jun 30, 2015
 *      Author: rashid
 *      Author: Jorge Silva <up201007483@alunos.dcc.fc.up.pt>
 */

/*****************************************************************/
void atomic_max_float_global(volatile global float *source, const float operand) {
  union {
    unsigned int intVal;
    float floatVal;
  } newVal;
  union {
    unsigned int intVal;
    float floatVal;
  } prevVal;

  do {
    prevVal.floatVal = *source;
    newVal.floatVal = max(prevVal.floatVal,operand);
  } while (prevVal.floatVal < newVal.floatVal && atomic_cmpxchg((volatile global unsigned int *)source, prevVal.intVal, newVal.intVal) != prevVal.intVal);
}
 /******************************************************************/
#define alpha (1.0 - 0.85)
#define error_threshold 0.015 //value to deem node convergence

typedef struct dPageRank {
  float value;
  unsigned int nout;
} PRResidual;

typedef void EdgeData;
typedef PRResidual NodeData;
//#include "graph_header.h"
//##########################################
//Graph header, created ::Tue Jun  2 16:02:26 2015

typedef struct _GraphType {
  uint _num_nodes;
  uint _num_edges;
  uint _node_data_size;
  uint _edge_data_size;
  uint _work_size; //added variable here
  __global NodeData *_node_data;
  __global uint *_out_index;
  __global uint *_out_neighbors;
 }GraphType;

uint getWork(__local GraphType * graph){ //return work size
  return graph->_work_size;
}

//call this once to initialize worksize
void setWork(__local GraphType * graph, uint num_nodes) {
  graph->_work_size = num_nodes;
}

uint in_neighbors_begin(__local GraphType * graph, uint node){
  return 0;
}
uint in_neighbors_end(__local GraphType * graph, uint node){
  return graph->_out_index[node+1]-graph->_out_index[node];
}
uint in_neighbors_next(__local GraphType * graph, uint node){
  return 1;
}
uint in_neighbors(__local GraphType * graph, uint node, uint nbr){
  return graph->_out_neighbors[graph->_out_index[node]+nbr];
}
uint out_neighbors_begin(__local GraphType * graph, uint node){
  return 0;
}
uint out_neighbors_end(__local GraphType * graph, uint node){
  return graph->_out_index[node+1]-graph->_out_index[node];
}
uint out_neighbors_next(__local GraphType * graph, uint node){
  return 1;
}
uint out_neighbors(__local GraphType * graph,uint node,  uint nbr){
  return graph->_out_neighbors[graph->_out_index[node]+nbr];
}
__global NodeData * node_data(__local GraphType * graph, uint node){
  return &graph->_node_data[node];
}
void initialize(__local GraphType * graph, __global uint *mem_pool){
  uint offset =4;
  graph->_num_nodes=mem_pool[0];
  graph->_num_edges=mem_pool[1];
  graph->_node_data_size=mem_pool[2];
  graph->_edge_data_size=mem_pool[3];
  graph->_node_data= (__global NodeData *)&mem_pool[offset];
  offset +=graph->_num_nodes* graph->_node_data_size;
  graph->_out_index=&mem_pool[offset];
  offset +=graph->_num_nodes + 1;
  graph->_out_neighbors=&mem_pool[offset];
  offset +=graph->_num_edges;
  //can't initialize here cause this is called everytime on pagerank
  //graph->_work_size=_num_nodes; //initialize work size 
}


//##########################################
__kernel void pagerank(__global int * graph_ptr,__global float* aux,  __global int* wl, int num_items) { 
  int my_id = get_global_id(0);
  __local GraphType graph;
  initialize(&graph, graph_ptr);
  //for (int i = my_id; i < num_items; i += total_threads) { //how to get the number of threads?
  if(my_id < num_items) { //need to switch to a for otherwise if the number of nodes is bigger than the threads this won't check all nodes
    if (wl[my_id] == 1) { //if node hasn't converged yet
      double sum = 0;
      __global NodeData * sdata = node_data(&graph, my_id);
      for(int i= out_neighbors_begin(&graph, my_id); i<out_neighbors_end(&graph, my_id); ++i) {
        int dst_id = out_neighbors(&graph, my_id, i);
        __global NodeData * ddata = node_data(&graph, dst_id);
        sum+= ddata->value / ddata->nout;
      }//end for
      float value= (1.0 - alpha) * sum + alpha;
      float diff = fabs(value - sdata->value);
      if (diff < error_threshold) { //if diff is smaller than the threshold then deem convergence
        wl[my_id] = 0;
        //I think this decrease won't work
        atomic_add(&graph._work_size,-1); //decrease the amount of work 
      }
      aux[my_id] = value;
    }
  }//end if
}//end kernel

__kernel void writeback(__global int * graph_ptr,__global float * aux,  int num_items) {
  int my_id = get_global_id(0);
  __local GraphType graph;
  initialize(&graph, graph_ptr);
  if(my_id < num_items) {
    __global NodeData * sdata = node_data(&graph, my_id);
    sdata->value = aux[my_id];
  }//end if
}//end kernel

__kernel void initialize_all(__global int * graph_ptr, __global float* aux_array, __global float* wl) {//, __global int* size_work) {
  int my_id = get_global_id(0);
  __local GraphType graph;
  initialize(&graph, graph_ptr);
  //printf ("IT Works\n");
  if(my_id < graph._num_nodes){ //same problem without the for
    atomic_add(&graph._work_size, 1); //add one to work
    wl[my_id] = 1; //initialize all nodes as work
    node_data(&graph, my_id)->value=1.0 - alpha;
    aux_array[my_id] = 1.0 - alpha;
    node_data(&graph, my_id)->nout=0;
  }//end if
}//end kernel

__kernel void initialize_nout(__global int * graph_ptr, __global float* aux_array, int num_items) {
  int my_id = get_global_id(0);
  __local GraphType graph;
  initialize(&graph, graph_ptr);
  if(my_id < graph._num_nodes){
    node_data(&graph, my_id)->value=1.0 - alpha;
    aux_array[my_id] = 1.0 - alpha;
    if(my_id < num_items){
      for(int i= out_neighbors_begin(&graph, my_id); i<out_neighbors_end(&graph, my_id); ++i) {
        int dst_id = out_neighbors(&graph, my_id, i);
        __global NodeData * dst_data = node_data(&graph, dst_id);
        atomic_add(&dst_data->nout,1);
   //         printf("Init[%d->%d]", my_id,dst_id);
      }//end for
    }
  }//end if
}//end kernel

__kernel void pagerank_term(__global int * graph_ptr,__global float* aux,  __global float * meta, int num_items) {
  int my_id = get_global_id(0);
  __local GraphType graph;
  initialize(&graph, graph_ptr);
  if(my_id < num_items) {
    double sum = 0;
    __global NodeData * sdata = node_data(&graph, my_id);
    for(int i= out_neighbors_begin(&graph, my_id); i<out_neighbors_end(&graph, my_id); ++i) {
      int dst_id = out_neighbors(&graph, my_id, i);
      __global NodeData * ddata = node_data(&graph, dst_id);
      sum+= ddata->value / ddata->nout;
    }//end for
    float value= (1.0 - alpha) * sum + alpha;
    float diff = fabs(value - sdata->value);
    atomic_max_float_global(&meta[0],diff);
    aux[my_id] = value;
  }//end if
}//end kernel
