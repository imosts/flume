#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>


int
main (int argc, char *argv[]){

  int handle = open("/home/testfile", O_RDWR | O_CREAT );
  int r=0;
  char buffer[256];
  for(int i=0; i<argc; i++){
    printf("%s ", argv[i]);
  }
  printf("\n");
  
  r = read(handle, buffer, 256);
  if (r > 0){
    buffer[r]='\0';
    printf("file starts with %s\n", buffer);
  } else if (r == 0){
    printf("file is empty\n");
  } else{
    printf("error reading file: %d\n", r);
  }
  close(handle);  

  r = link("/home/testfile", "/home/testfile3");
  printf("link returned %d\n", r);

  r = rename("/home/testfile", "/home/testfile2");
  printf("rename returned %d\n", r);

  r = symlink("/home/testfile3", "/home/testfile4");
  printf("symlink returned %d\n", r);

  r = unlink("/home/testfile2");
  printf("unlink returned %d\n", r);

  r = unlink("/home/testfile3");
  printf("unlink returned %d\n", r);

  r = unlink("/home/testfile4");
  printf("unlink returned %d\n", r);

  return(0);
} 
